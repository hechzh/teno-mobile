package com.teno.app;

import android.app.*;
import android.content.*;
import android.os.*;
import org.json.*;
import java.io.*;
import java.util.concurrent.*;

public final class TeamAudioUploadService extends Service {
    static volatile boolean active=false;static volatile String message="";
    final ExecutorService worker=Executors.newSingleThreadExecutor();
    @Override public IBinder onBind(Intent i){return null;}
    @Override public void onCreate(){super.onCreate();RecorderService.channel(this,"upload","Uploads and processing");}
    Notification notice(String text){return new Notification.Builder(this,"upload").setSmallIcon(R.drawable.ic_app).setContentTitle("Teno · Team audio").setContentText(text).setOngoing(true).setContentIntent(RecorderService.home(this)).build();}
    @Override public int onStartCommand(Intent i,int flags,int startId){
        if(active)return START_NOT_STICKY;
        if(i==null){stopSelf();return START_NOT_STICKY;}
        Store store=new Store(this);String scope=i.getStringExtra("scope"),id=i.getStringExtra("id");
        if(scope==null||scope.isEmpty()||!scope.equals(store.scope())){stopSelf();return START_NOT_STICKY;}
        active=true;message="Uploading team audio";startForeground(13,notice(message));
        worker.execute(()->{TeamAudioStore drafts=new TeamAudioStore(this,store);JSONObject d=null;
            PowerManager.WakeLock wake=((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"Teno:TeamUpload");wake.acquire(30*60*1000L);
            try{d=drafts.load(id);if(!scope.equals(d.optString("scope")))throw new IOException("Sign in to the original account");
                d.put("status","uploading");drafts.save(d);File file=new File(d.getString("path"));
                if(!file.getCanonicalPath().startsWith(drafts.folder.getCanonicalPath()+File.separator)||!file.isFile()||file.length()==0||file.length()>250L*1024*1024)throw new IOException("Select an audio file up to 250 MiB");
                JSONObject fields=new JSONObject().put("client_id",id).put("share_with_team","true").put("title",d.getString("title")).put("language",store.language());
                final long[] last={0};JSONObject result=new Api(store).upload("/api/v1/teams/"+d.getString("team_id")+"/meeting-audio-imports",file,d.optString("filename","recording.wav"),fields,(sent,total)->{
                    if(!scope.equals(store.scope()))throw new IllegalStateException("Account changed. Retry from the original account.");
                    message="Uploading "+sent*100/Math.max(1,total)+"%";
                    if(SystemClock.elapsedRealtime()-last[0]>1000){last[0]=SystemClock.elapsedRealtime();((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(13,notice(message));}
                });
                d.put("status","uploaded").put("import_id",result.getString("id")).put("meeting_id",result.getString("meeting_id")).remove("error");drafts.save(d);message="Audio uploaded. Processing on the server.";
            }catch(Exception e){message="Upload failed: "+e.getMessage();if(d!=null)try{d.put("status","failed").put("error",message);drafts.save(d);}catch(Exception ignored){}
            }finally{if(wake.isHeld())wake.release();active=false;stopForeground(STOP_FOREGROUND_REMOVE);stopSelf(startId);}
        });return START_NOT_STICKY;
    }
    @Override public void onTimeout(int startId,int type){stopForeground(STOP_FOREGROUND_REMOVE);stopSelf(startId);}
    @Override public void onDestroy(){worker.shutdown();super.onDestroy();}
}
