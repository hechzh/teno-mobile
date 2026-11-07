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
    private static volatile boolean accountPaused;
    private static volatile Api activeApi;
    private static final Object ACCOUNT_LOCK=new Object();
    static void pauseAccount(Context context)throws Exception{
        accountPaused=true;
        ((JobScheduler)context.getSystemService(Context.JOB_SCHEDULER_SERVICE)).cancel(JOB_ID);
        Api api=activeApi;if(api!=null)api.cancel();
        long until=android.os.SystemClock.elapsedRealtime()+15000;
        synchronized(ACCOUNT_LOCK){while(running.get()&&android.os.SystemClock.elapsedRealtime()<until)ACCOUNT_LOCK.wait(100);}
        if(running.get()){accountPaused=false;throw new IOException("Upload is stopping. Try signing out again in a moment.");}
        TransferService.message="";
    }
    static void resumeAccount(Context context){accountPaused=false;resume(context);}
    static final int JOB_ID=4301;
    static boolean remote(JSONObject d){return !d.optString("recording_id").isEmpty()||!d.optString("file_id").isEmpty();}
    static String parentRecording(Store store,JSONObject d){
        if(!d.optString("recording_id_parent").isEmpty())return d.optString("recording_id_parent");
        String parent=d.optString("parent_local_id");if(parent.isEmpty())return "";
        try{
            if(!parent.startsWith("jwd:"))return store.draft(parent).optString("recording_id");
            String[] parts=parent.substring(4).split("\\|",2);JSONArray all=store.drafts();
            for(int i=0;i<all.length();i++){JSONObject item=all.getJSONObject(i);if(parts.length==2&&item.optString("jwd_device").equals(parts[0])&&item.optString("jwd_file").equals(parts[1]))return item.optString("recording_id");}
        }catch(Exception ignored){}return "";
    }
    interface Progress {void update(String message);}
    static void saved(Context context,JSONObject draft)throws Exception{
        Store store=new Store(context);
        if(store.autoUpload())enqueue(store,draft.optString("id"),true);
        resume(context);
    }
    static void enqueue(Store store,String id,boolean automatic)throws Exception{
        synchronized(Store.class){
            JSONObject d=store.draft(id);
            if(remote(d)||d.optString("status").equals("recording")||d.optString("status").equals("invalid"))return;
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
    static boolean requested(Store store,JSONObject d){return d.optBoolean("upload_requested")&&!remote(d)&&d.optString("scope").equals(store.scope())&&(!d.optBoolean("upload_automatic")||store.autoUpload())&&(d.optString("parent_local_id").isEmpty()||!parentRecording(store,d).isEmpty());}
    static String label(Store store,JSONObject d){
        if(remote(d))return d.optString("status").equals("ready")?"Ready":d.optString("status").equals("processing_failed")?"Processing needs attention · Local copy kept":"Processing";
        if(!d.optString("parent_local_id").isEmpty()&&parentRecording(store,d).isEmpty())return "Saved on this phone · Waiting for recording";
        if(d.optString("status").equals("failed"))return "Upload needs attention · Local audio is safe";
        if(d.optBoolean("upload_automatic")&&!store.autoUpload())return "Saved on this phone · Automatic cloud processing is off";
        if(d.optBoolean("upload_requested"))return d.optString("status").equals("uploading")?"Uploading":store.wifiUpload()?"Queued · Waiting for Wi-Fi":"Queued · Waiting for connection";
        return "Saved on this phone";
    }
    static void resume(Context context){
        if(accountPaused||running.get())return;
        schedule(context);
        Store store=new Store(context);if(store.scope().isEmpty()||store.token("access_token").isEmpty()||running.get()||!networkAllowed(context,store))return;
        JSONArray ds=store.drafts();for(int i=0;i<ds.length();i++){JSONObject d=ds.optJSONObject(i);if(d!=null&&requested(store,d)&&d.optLong("upload_retry_at")<=System.currentTimeMillis()){
            try{context.startForegroundService(new Intent(context,TransferService.class));}catch(RuntimeException ignored){/* Persisted job resumes when Android permits it. */}return;
        }}
    }
    static void schedule(Context context){
        if(accountPaused||running.get())return;
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
            while(!accountPaused&&!Thread.currentThread().isInterrupted()&&owner.equals(store.scope())&&!owner.isEmpty()&&!store.token("access_token").isEmpty()&&networkAllowed(context,store)){
                JSONObject next=null;JSONArray ds=store.drafts();
                for(int i=ds.length()-1;i>=0;i--){JSONObject d=ds.optJSONObject(i);if(d!=null&&requested(store,d)&&d.optLong("upload_retry_at")<=System.currentTimeMillis()){next=d;break;}}
                if(next==null)break;upload(context,store,next.optString("id"),owner,progress);
            }
        }finally{activeApi=null;TransferService.draftId="";TransferService.active=false;running.set(false);synchronized(ACCOUNT_LOCK){ACCOUNT_LOCK.notifyAll();}}
    }
    private static void upload(Context context,Store store,String id,String owner,Progress progress){
        TransferService.draftId=id;TransferService.active=true;Api api=new Api(store);
        activeApi=api;if(accountPaused){api.cancel();return;}
        try{
            JSONObject draft;
            synchronized(Store.class){draft=store.draft(id);draft.put("status","uploading").put("upload_attempts",draft.optInt("upload_attempts")+1).remove("error");store.save(draft);}
            File audio=new File(draft.getString("path"));if(!audio.isFile()||audio.length()==0)throw new IOException("No valid audio file found");
            boolean document=draft.optString("kind").equals("file");
            JSONObject fields=new JSONObject().put("client_id",id);
            if(document){String parent=parentRecording(store,draft);if(!parent.isEmpty())fields.put("recording_id",parent);if(draft.has("at_ms"))fields.put("at_ms",String.valueOf(draft.getLong("at_ms")));}
            else fields.put("title",draft.getString("title")).put("language",store.language()).put("personal_mode","true").put("source",draft.optString("source").equals("import")?"import":draft.optString("source").equals("jwd_ble")?"device":"phone");
            if(!draft.optString("live_session_id").isEmpty())fields.put("live_session_id",draft.getString("live_session_id"));
            JSONObject result=api.upload(document?"/api/v1/files":"/api/v1/recordings",audio,document?draft.getString("title"):audio.getName(),fields,(sent,total)->{TransferService.message="Uploading "+(total==0?0:sent*100/total)+"%";progress.update(TransferService.message);});
            if(!owner.equals(store.scope()))return;
            synchronized(Store.class){draft=store.draft(id);draft.put(document?"file_id":"recording_id",result.getString(document?"file_id":"recording_id")).put("job_id",result.isNull("job_id")?"":result.optString("job_id")).put("status",result.isNull("job_id")?"uploaded":"processing").put("upload_requested",false);store.save(draft);}
            if(!document&&!draft.optString("notes").trim().isEmpty()){
                try{
                    JSONArray marks=new JSONArray();java.util.regex.Matcher matcher=java.util.regex.Pattern.compile("(?m)^\\[(\\d+):(\\d{2})\\]\\s*(.*)$").matcher(draft.optString("notes"));
                    while(matcher.find())marks.put(new JSONObject().put("at_ms",(Long.parseLong(matcher.group(1))*60+Long.parseLong(matcher.group(2)))*1000).put("text",matcher.group(3)));
                    api.request("PATCH","/api/v1/recordings/"+result.getString("recording_id")+"/metadata",new JSONObject().put("source",draft.optString("source").equals("import")?"import":draft.optString("source").equals("jwd_ble")?"device":"phone").put("marks",marks));
                }catch(Exception ignored){/* Original timestamped notes remain on this phone. */}
                File note=new File(context.getCacheDir(),"context-"+id+".md");try(FileOutputStream out=new FileOutputStream(note)){out.write(draft.optString("notes").getBytes(StandardCharsets.UTF_8));}
                try{api.upload("/api/v1/recordings/"+result.getString("recording_id")+"/attachments",note,"Recording-notes.md",null,null);}
                catch(Exception e){synchronized(Store.class){JSONObject current=store.draft(id);current.put("note_error","Audio uploaded. Add the notes from recording details.");store.save(current);}}finally{note.delete();}
            }
            ProcessingJobService.schedule(context);
            TransferService.message="Processing · Local copy kept";
        }catch(Exception e){
            TransferService.message="Upload paused · Local copy kept";
            if(owner.equals(store.scope()))try{synchronized(Store.class){JSONObject d=store.draft(id);if(remote(d))return;
                if(accountPaused){d.put("status","queued").put("upload_requested",true).put("upload_retry_at",0).put("upload_attempts",Math.max(0,d.optInt("upload_attempts")-1)).remove("error");store.save(d);return;}
                boolean retry=!(e instanceof Api.Failure)||((Api.Failure)e).status==408||((Api.Failure)e).status==429||((Api.Failure)e).status>=500;
                retry=retry&&d.optInt("upload_attempts")<3;
                d.put("status",retry?"queued":"failed").put("upload_requested",retry).put("upload_retry_at",System.currentTimeMillis()+30000L*(1L<<Math.min(3,d.optInt("upload_attempts")))).put("error",e.getMessage());store.save(d);
            }}catch(Exception ignored){}
        }
    }
}
