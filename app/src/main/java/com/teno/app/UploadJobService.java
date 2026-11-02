package com.teno.app;

import android.app.job.*;

/** Android resumes persisted uploads after connectivity changes or process death. */
public final class UploadJobService extends JobService {
    private Thread worker;private volatile boolean stopped;
    @Override public boolean onStartJob(JobParameters params){
        if(!UploadQueue.running.compareAndSet(false,true))return false;
        stopped=false;TransferService.active=true;worker=new Thread(()->{UploadQueue.drain(this,text->{});if(!stopped)jobFinished(params,false);UploadQueue.schedule(this);},"TenoUploadJob");worker.start();return true;
    }
    @Override public boolean onStopJob(JobParameters params){stopped=true;if(worker!=null)worker.interrupt();return true;}
}
