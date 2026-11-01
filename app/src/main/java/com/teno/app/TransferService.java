package com.teno.app;

import android.app.*;
import android.content.*;
import android.os.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;

public final class TransferService extends Service {
    public static volatile boolean active=false;
    public static volatile String message="",draftId="";
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    @Override public IBinder onBind(Intent i){return null;}
    @Override public void onCreate(){super.onCreate();RecorderService.channel(this,"upload","Uploads and processing");}
    private Notification notification(String text){return new Notification.Builder(this,"upload").setSmallIcon(R.drawable.ic_app).setContentTitle("Teno · Uploading recording").setContentText(text).setContentIntent(RecorderService.home(this)).setOngoing(true).build();}
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(active)return START_NOT_STICKY;
        if(intent==null||intent.getStringExtra("id")==null){stopSelf();return START_NOT_STICKY;}
        active=true;draftId=intent.getStringExtra("id");message="Uploading";startForeground(11,notification(message));
        worker.execute(()->{
            Store store=new Store(this);Api api=new Api(store);JSONObject draft=null;
            try{
                draft=store.draft(draftId);draft.put("status","uploading").remove("error");store.save(draft);
                File audio=new File(draft.getString("path"));if(!audio.isFile()||audio.length()==0)throw new IOException("No valid audio file found");
                JSONObject fields=new JSONObject().put("client_id",draftId).put("title",draft.getString("title")).put("language",draft.optString("language","zh-CN"));
                if(!draft.optString("live_session_id").isEmpty())fields.put("live_session_id",draft.getString("live_session_id"));
                final long[] last={0};
                JSONObject result=api.upload("/api/v1/recordings",audio,audio.getName(),fields,(sent,total)->{
                    message="Uploading "+(total==0?0:sent*100/total)+"%";
                    if(SystemClock.elapsedRealtime()-last[0]>1000){last[0]=SystemClock.elapsedRealtime();((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(11,notification(message));}
                });
                draft.put("recording_id",result.getString("recording_id")).put("job_id",result.isNull("job_id")?"":result.optString("job_id")).put("status",result.isNull("job_id")?"uploaded":"processing");store.save(draft);
                if(!draft.optString("notes").trim().isEmpty()){
                    File note=new File(getCacheDir(),"context-"+draftId+".md");try(FileOutputStream out=new FileOutputStream(note)){out.write(draft.optString("notes").getBytes(StandardCharsets.UTF_8));}
                    try{api.upload("/api/v1/recordings/"+result.getString("recording_id")+"/attachments",note,"Recording-notes.md",null,null);}catch(Exception e){draft.put("note_error","Audio uploaded, but notes could not be added. Add them from the recording details.");store.save(draft);}finally{note.delete();}
                }
                message="Upload complete. Processing recording…";
            }catch(Exception e){message="Upload failed: "+e.getMessage();if(draft!=null)try{draft.put("status","failed").put("error",message);store.save(draft);}catch(Exception ignored){} }
            finally{active=false;stopForeground(STOP_FOREGROUND_REMOVE);stopSelf(startId);}
        });return START_NOT_STICKY;
    }
    @Override public void onDestroy(){worker.shutdown();super.onDestroy();}
}
