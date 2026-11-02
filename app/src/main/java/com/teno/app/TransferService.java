package com.teno.app;

import android.app.*;
import android.content.*;
import android.os.*;
import java.util.concurrent.*;

public final class TransferService extends Service {
    public static volatile boolean active=false;
    public static volatile String message="",draftId="";
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final Handler handler=new Handler(Looper.getMainLooper());private int latestStart;private boolean working;private long lastNotice;
    @Override public IBinder onBind(Intent i){return null;}
    @Override public void onCreate(){super.onCreate();RecorderService.channel(this,"upload","Uploads and processing");}
    private Notification notification(String text){return new Notification.Builder(this,"upload").setSmallIcon(R.drawable.ic_app).setContentTitle("Teno · Syncing recordings").setContentText(text).setContentIntent(RecorderService.home(this)).setOngoing(true).build();}
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        latestStart=startId;startForeground(11,notification("Local audio is kept while uploading"));
        if(intent!=null&&intent.hasExtra("id"))try{UploadQueue.enqueue(new Store(this),intent.getStringExtra("id"),false);}catch(Exception e){message=e.getMessage();}
        if(!working){if(UploadQueue.running.compareAndSet(false,true)){working=true;active=true;worker.execute(()->{UploadQueue.drain(this,text->{if(SystemClock.elapsedRealtime()-lastNotice>1000){lastNotice=SystemClock.elapsedRealtime();((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(11,notification(text));}});handler.post(()->{working=false;stopForeground(STOP_FOREGROUND_REMOVE);stopSelf(latestStart);UploadQueue.schedule(this);});});}else{stopForeground(STOP_FOREGROUND_REMOVE);stopSelf(startId);}}
        return START_NOT_STICKY;
    }
    @Override public void onDestroy(){worker.shutdown();super.onDestroy();}
}
