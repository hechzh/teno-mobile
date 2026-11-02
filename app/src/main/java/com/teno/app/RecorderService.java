package com.teno.app;

import android.app.*;
import android.content.*;
import android.media.*;
import android.os.*;
import org.json.*;
import java.io.*;

public final class RecorderService extends Service {
    public static volatile boolean active=false,paused=false,finishing=false;
    public static volatile String draftId="",error="";
    public static volatile long started=0,pausedAt=0,pausedTotal=0,capturedBytes=0;
    public static volatile LiveTranscriber live;
    private final Object captureLock=new Object();private AudioRecord recorder;private Store store;private PowerManager.WakeLock wake;
    private volatile boolean keep=true;private Thread capture;
    @Override public IBinder onBind(Intent i){return null;}
    @Override public void onCreate(){super.onCreate();store=new Store(this);channel(this,"recording","Recording");}
    public static PendingIntent home(Context c){return PendingIntent.getActivity(c,0,new Intent(c,MainActivity.class).putExtra("open_recording",true),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);}
    public static void channel(Context c,String id,String name){((NotificationManager)c.getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(new NotificationChannel(id,name,NotificationManager.IMPORTANCE_LOW));}
    private Notification notification(){PendingIntent stop=PendingIntent.getService(this,2,new Intent(this,RecorderService.class).setAction("stop"),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        return new Notification.Builder(this,"recording").setSmallIcon(R.drawable.ic_app).setContentTitle(finishing?"Teno · Saving recording":paused?"Teno · Recording paused":"Teno · Recording").setContentText("Audio is saved on this phone.").setContentIntent(home(this)).setOngoing(true).addAction(new Notification.Action.Builder(null,"Stop and save",stop).build()).build();}
    public static long elapsed(){return capturedBytes/32;}
    @Override public int onStartCommand(Intent intent,int flags,int id){
        if(intent==null){stopSelf();return START_NOT_STICKY;}String action=intent.getAction();
        try{
            if("start".equals(action)&&!active&&!finishing){
                JSONObject draft=store.draft(intent.getStringExtra("id"));if(store.scope().isEmpty())throw new IOException("Sign in before recording");
                error="";draftId=draft.getString("id");paused=false;pausedTotal=0;capturedBytes=0;keep=true;startForeground(10,notification());
                if(checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)!=android.content.pm.PackageManager.PERMISSION_GRANTED)throw new SecurityException("Allow microphone access in Android Settings.");
                int size=Math.max(6400,AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT)*2);
                recorder=new AudioRecord(MediaRecorder.AudioSource.MIC,16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,size);
                if(recorder.getState()!=AudioRecord.STATE_INITIALIZED)throw new IOException("The microphone could not be opened");
                live=draft.optBoolean("live",true)?new LiveTranscriber(store,draftId,draft.optString("title"),draft.optString("language","zh-CN")):null;
                recorder.startRecording();active=true;started=SystemClock.elapsedRealtime();draft.put("status","recording");store.save(draft);
                wake=((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"Teno:Recording");wake.acquire(3600000);
                capture=new Thread(()->capture(draft),"TenoPcmCapture");capture.start();
            }else if("pause".equals(action)&&active){synchronized(captureLock){paused=!paused;if(live!=null)live.pause(paused);}((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(10,notification());}
            else if("retry_live".equals(action)&&live!=null)live.retry();
            else if("stop".equals(action)||"discard".equals(action)){keep=!"discard".equals(action);stopCapture();}
        }catch(Exception e){error="Recording could not start. "+e.getMessage();active=false;try{JSONObject failed=store.draft(draftId);failed.put("status","invalid").put("error",error);store.save(failed);}catch(Exception ignored){}if(recorder!=null){recorder.release();recorder=null;}if(live!=null)live.close();stopForeground(STOP_FOREGROUND_REMOVE);stopSelf();}
        return START_NOT_STICKY;
    }
    private void stopCapture(){active=false;finishing=capture!=null&&capture.isAlive();if(recorder!=null)try{recorder.stop();}catch(Exception ignored){}if(finishing)((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(10,notification());else{stopForeground(STOP_FOREGROUND_REMOVE);stopSelf();}}
    private void capture(JSONObject original){boolean valid=false;String reusable="";String owner=store.scope();
        try(RandomAccessFile out=new RandomAccessFile(original.getString("path"),"rw")){
            out.setLength(0);out.write(JwdAudio.wavHeader(0));byte[] buffer=new byte[1600];
            while(active){int n=recorder.read(buffer,0,buffer.length,AudioRecord.READ_BLOCKING);if(n<0){if(active)throw new IOException("Microphone interrupted. The saved audio has been kept.");break;}
                synchronized(captureLock){if(!paused&&active&&n>0){out.write(buffer,0,n);capturedBytes+=n;if(live!=null)live.feed(buffer,n);}}
                if(capturedBytes>=103680000){active=false;error="The 54-minute recording limit was reached. Audio has been saved.";}
            }
            out.seek(0);out.write(JwdAudio.wavHeader(capturedBytes));out.getFD().sync();valid=capturedBytes>=3200;
        }catch(Exception e){error=e.getMessage();valid=capturedBytes>=3200;try(RandomAccessFile repair=new RandomAccessFile(original.optString("path"),"rw")){repair.seek(0);repair.write(JwdAudio.wavHeader(Math.max(0,repair.length()-44)));}catch(Exception ignored){valid=false;}}
        finally{
            active=false;finishing=true;paused=false;if(recorder!=null){try{recorder.stop();}catch(Exception ignored){}recorder.release();recorder=null;}
            if(live!=null){if(keep&&valid)reusable=live.finish();else live.close();}
            try{if(owner.equals(store.scope())){JSONObject d=store.draft(draftId);d.put("duration_ms",capturedBytes/32).put("status",valid?"local":"invalid").put("live_session_id",reusable).put("live_complete",!reusable.isEmpty());
                if(live!=null)d.put("live_segments",live.segments());if(!error.isEmpty())d.put("error",error);store.save(d);if(!keep)store.deleteDraft(d);else if(valid)UploadQueue.saved(this,d);}}
            catch(Exception e){error="Audio saved, but its details could not be updated.";}
            if(wake!=null&&wake.isHeld())wake.release();finishing=false;stopForeground(STOP_FOREGROUND_REMOVE);stopSelf();
        }
    }
    @Override public void onDestroy(){if(active)stopCapture();super.onDestroy();}
}
