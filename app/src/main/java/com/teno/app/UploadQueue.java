package com.teno.app;

import android.app.job.*;
import android.content.*;
import android.net.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicBoolean;

/** Persist requests before starting work; retry the same file and client_id. */
final class UploadQueue {
    static final AtomicBoolean running=new AtomicBoolean();
    static final int JOB_ID=4301;
    interface Progress {void update(String message);}
    static void saved(Context context,JSONObject draft)throws Exception{
        Store store=new Store(context);
        if(store.autoUpload())enqueue(store,draft.optString("id"),true);
        resume(context);
    }
    static void enqueue(Store store,String id,boolean automatic)throws Exception{
        synchronized(Store.class){
            JSONObject d=store.draft(id);
            if(!d.optString("recording_id").isEmpty()||d.optString("status").equals("recording")||d.optString("status").equals("invalid"))return;
            if(!d.optString("scope").equals(store.scope()))throw new IOException("Sign in to the recording's account.");
            if(!new File(d.getString("path")).isFile())throw new IOException("The local recording is unavailable.");
            if(d.optBoolean("upload_requested")&&(d.optString("status").equals("uploading")||automatic))return;
            d.put("upload_requested",true).put("upload_automatic",automatic).put("upload_attempts",0).put("upload_retry_at",0).put("status","queued").remove("error");store.save(d);
        }
    }
    static boolean networkAllowed(Context context,Store store){
        ConnectivityManager cm=(ConnectivityManager)context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkCapabilities caps=cm.getNetworkCapabilities(cm.getActiveNetwork());
        return caps!=null&&caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)&&(!store.wifiUpload()||caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI));
    }
    static boolean requested(Store store,JSONObject d){return d.optBoolean("upload_requested")&&d.optString("recording_id").isEmpty()&&d.optString("scope").equals(store.scope())&&(!d.optBoolean("upload_automatic")||store.autoUpload());}
    static String label(Store store,JSONObject d){
        if(!d.optString("recording_id").isEmpty())return "Processing";
        if(d.optString("status").equals("failed"))return "Upload needs attention · Local audio is safe";
        if(d.optBoolean("upload_automatic")&&!store.autoUpload())return "Saved on this phone · Automatic cloud processing is off";
        if(d.optBoolean("upload_requested"))return d.optString("status").equals("uploading")?"Uploading":store.wifiUpload()?"Queued · Waiting for Wi-Fi":"Queued · Waiting for connection";
        return "Saved on this phone";
    }
    static void resume(Context context){
        if(running.get())return;
        schedule(context);
        Store store=new Store(context);if(store.scope().isEmpty()||store.token("access_token").isEmpty()||running.get()||!networkAllowed(context,store))return;
        JSONArray ds=store.drafts();for(int i=0;i<ds.length();i++){JSONObject d=ds.optJSONObject(i);if(d!=null&&requested(store,d)&&d.optLong("upload_retry_at")<=System.currentTimeMillis()){
            try{context.startForegroundService(new Intent(context,TransferService.class));}catch(RuntimeException ignored){/* Persisted job resumes when Android permits it. */}return;
        }}
    }
    static void schedule(Context context){
        if(running.get())return;
        Store store=new Store(context);if(store.scope().isEmpty()||store.token("access_token").isEmpty())return;
        long earliest=Long.MAX_VALUE;JSONArray ds=store.drafts();for(int i=0;i<ds.length();i++){JSONObject d=ds.optJSONObject(i);if(d!=null&&requested(store,d))earliest=Math.min(earliest,d.optLong("upload_retry_at"));}
        if(earliest==Long.MAX_VALUE)return;
        JobInfo.Builder builder=new JobInfo.Builder(JOB_ID,new ComponentName(context,UploadJobService.class)).setRequiredNetworkType(store.wifiUpload()?JobInfo.NETWORK_TYPE_UNMETERED:JobInfo.NETWORK_TYPE_ANY).setMinimumLatency(Math.max(networkAllowed(context,store)?1000:30000,earliest-System.currentTimeMillis())).setPersisted(true);
        if(store.wifiUpload()&&android.os.Build.VERSION.SDK_INT>=28)builder.setRequiredNetwork(new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build());
        JobInfo job=builder.build();
        ((JobScheduler)context.getSystemService(Context.JOB_SCHEDULER_SERVICE)).schedule(job);
    }
    static void drain(Context context,Progress progress){
        Store store=new Store(context);String owner=store.scope();
        try{
            while(!Thread.currentThread().isInterrupted()&&owner.equals(store.scope())&&!owner.isEmpty()&&!store.token("access_token").isEmpty()&&networkAllowed(context,store)){
                JSONObject next=null;JSONArray ds=store.drafts();
                for(int i=ds.length()-1;i>=0;i--){JSONObject d=ds.optJSONObject(i);if(d!=null&&requested(store,d)&&d.optLong("upload_retry_at")<=System.currentTimeMillis()){next=d;break;}}
                if(next==null)break;upload(context,store,next.optString("id"),owner,progress);
            }
        }finally{TransferService.draftId="";TransferService.active=false;running.set(false);}
    }
    private static void upload(Context context,Store store,String id,String owner,Progress progress){
        TransferService.draftId=id;TransferService.active=true;Api api=new Api(store);
        try{
            JSONObject draft;
            synchronized(Store.class){draft=store.draft(id);draft.put("status","uploading").put("upload_attempts",draft.optInt("upload_attempts")+1).remove("error");store.save(draft);}
            File audio=new File(draft.getString("path"));if(!audio.isFile()||audio.length()==0)throw new IOException("No valid audio file found");
            JSONObject fields=new JSONObject().put("client_id",id).put("title",draft.getString("title")).put("language",draft.optString("language","zh-CN"));
            if(!draft.optString("live_session_id").isEmpty())fields.put("live_session_id",draft.getString("live_session_id"));
            JSONObject result=api.upload("/api/v1/recordings",audio,audio.getName(),fields,(sent,total)->{TransferService.message="Uploading "+(total==0?0:sent*100/total)+"%";progress.update(TransferService.message);});
            if(!owner.equals(store.scope()))return;
            synchronized(Store.class){draft=store.draft(id);draft.put("recording_id",result.getString("recording_id")).put("job_id",result.isNull("job_id")?"":result.optString("job_id")).put("status",result.isNull("job_id")?"uploaded":"processing").put("upload_requested",false);store.save(draft);}
            if(!draft.optString("notes").trim().isEmpty()){
                File note=new File(context.getCacheDir(),"context-"+id+".md");try(FileOutputStream out=new FileOutputStream(note)){out.write(draft.optString("notes").getBytes(StandardCharsets.UTF_8));}
                try{api.upload("/api/v1/recordings/"+result.getString("recording_id")+"/attachments",note,"Recording-notes.md",null,null);}
                catch(Exception e){synchronized(Store.class){JSONObject current=store.draft(id);current.put("note_error","Audio uploaded. Add the notes from recording details.");store.save(current);}}finally{note.delete();}
            }
            TransferService.message="Processing recording · Local copy kept";
        }catch(Exception e){
            TransferService.message="Upload paused · Local copy kept";
            if(owner.equals(store.scope()))try{synchronized(Store.class){JSONObject d=store.draft(id);if(!d.optString("recording_id").isEmpty())return;
                boolean retry=!(e instanceof Api.Failure)||((Api.Failure)e).status==408||((Api.Failure)e).status==429||((Api.Failure)e).status>=500;
                retry=retry&&d.optInt("upload_attempts")<3;
                d.put("status",retry?"queued":"failed").put("upload_requested",retry).put("upload_retry_at",System.currentTimeMillis()+30000L*(1L<<Math.min(3,d.optInt("upload_attempts")))).put("error",e.getMessage());store.save(d);
            }}catch(Exception ignored){}
        }
    }
}
