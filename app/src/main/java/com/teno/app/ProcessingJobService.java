package com.teno.app;
import android.app.*;
import android.app.job.*;
import android.content.*;
import org.json.*;

/** Persisted completion polling; Android scheduling can delay a completion notice. */
public final class ProcessingJobService extends JobService {
    static final int ID=4302;volatile boolean stopped;
    static void schedule(Context c){
        Store s=new Store(c);if(s.scope().isEmpty())return;
        ((JobScheduler)c.getSystemService(JOB_SCHEDULER_SERVICE)).schedule(new JobInfo.Builder(ID,new ComponentName(c,ProcessingJobService.class))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setMinimumLatency(15000).setPersisted(true).build());
    }
    @Override public boolean onStartJob(JobParameters params){stopped=false;new Thread(()->{boolean pending=false;Store store=new Store(this);String owner=store.scope();
        try{Api api=new Api(store);JSONArray drafts=store.drafts();for(int i=0;i<drafts.length()&&!stopped&&owner.equals(store.scope());i++){
            JSONObject d=drafts.getJSONObject(i);if(!UploadQueue.remote(d)||d.optBoolean("ready_notified"))continue;
            boolean file=!d.optString("file_id").isEmpty();
            JSONObject state;
            try{state=api.get(file?"/api/v1/files/"+d.getString("file_id"):"/api/v1/personal/recordings/"+d.getString("recording_id")+"/processing");}
            catch(Api.Failure e){if(e.status!=404)throw e;state=new JSONObject().put("status","failed").put("error",new JSONObject().put("message","Cloud content is unavailable. The local copy is kept."));}
            boolean failed=state.optString("status").equals("failed");
            if(!failed&&!state.optString("status").equals("ready")){pending=true;continue;}
            if(!owner.equals(store.scope())||stopped)break;
            synchronized(Store.class){JSONObject current=store.draft(d.getString("id"));current.put("status",failed?"processing_failed":"ready").put("ready_notified",true);
                if(failed)current.put("error",state.optJSONObject("error")==null?"Processing failed. Open the cloud file to retry.":state.getJSONObject("error").optString("message"));
                else{current.remove("error");current.put("processing_message",state.optString("message"));}store.save(current);}
            if(getSharedPreferences("teno.personal",0).getBoolean("notifications."+owner,true)){
                RecorderService.channel(this,"results","Ready notes");Intent intent=new Intent(this,MainActivity.class);
                if(!file)intent.putExtra("recording_id",d.getString("recording_id"));
                PendingIntent open=PendingIntent.getActivity(this,d.getString("id").hashCode(),intent,PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
                try{((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(d.getString("id").hashCode(),new Notification.Builder(this,"results").setSmallIcon(R.drawable.ic_app).setContentTitle(failed?"Teno · Processing needs attention":"Teno · Ready").setContentText(d.optString("title")).setContentIntent(open).setAutoCancel(true).build());}catch(SecurityException ignored){}
            }
        }}catch(Exception e){pending=true;}finally{if(!stopped)jobFinished(params,pending);}
    },"teno-results").start();return true;}
    @Override public boolean onStopJob(JobParameters params){stopped=true;return true;}
}
