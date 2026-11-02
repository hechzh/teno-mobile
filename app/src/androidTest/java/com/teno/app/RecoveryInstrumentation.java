package com.teno.app;

import android.app.*;
import android.app.job.*;
import android.content.*;
import android.graphics.Bitmap;
import android.os.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/** Two runs separated by emulator force-stop; no production traffic. */
public final class RecoveryInstrumentation extends Instrumentation {
    String phase;Context context;Store store;MainActivity main;FlowInstrumentation fixture;
    final JSONArray checks=new JSONArray();
    void check(boolean ok,String name)throws Exception{checks.put(new JSONObject().put("check",name).put("passed",ok));if(!ok)throw new IOException(name);}
    @Override public void onCreate(Bundle args){super.onCreate(args);phase=args.getString("phase","offline");start();}
    void ui(Runnable r)throws Exception{runOnMainSync(r);waitForIdleSync();Thread.sleep(200);}
    @Override public void onStart(){context=getTargetContext();boolean ok=false;JSONObject report=new JSONObject();
        try{
            if(!context.getPackageName().equals("com.teno.app.flowverification"))throw new IOException("Isolated application required");
            context.getSharedPreferences("teno",0).edit().remove("jwd.last_address").remove("jwd.last_name").commit();store=new Store(context);
            if(phase.equals("offline")){
                store.base("http://127.0.0.1:9");store.identity("Recovery fixture","offline-recovery");store.tokens(new JSONObject().put("access_token","offline-fixture-only"));store.markNativePreferences();store.recordingOptions(true,false,false);
                check(!UploadQueue.networkAllowed(context,store),"network_is_actually_disconnected");
                JSONObject d=store.newDraft("Offline saved recording",".wav");try(FileOutputStream out=new FileOutputStream(d.getString("path"))){out.write(JwdAudio.wavHeader(64000));out.write(new byte[64000]);out.getFD().sync();}d.put("duration_ms",2000);store.save(d);UploadQueue.saved(context,d);
                context.getSharedPreferences("recovery-test",0).edit().putString("id",d.getString("id")).commit();
                check(store.draft(d.getString("id")).optBoolean("upload_requested")&&!UploadQueue.running.get(),"offline_local_file_queued_without_starting_upload");
                JobInfo job=((JobScheduler)context.getSystemService(Context.JOB_SCHEDULER_SERVICE)).getPendingJob(UploadQueue.JOB_ID);
                check(job!=null&&job.isPersisted(),"upload_has_persisted_android_job");
            }else{
                String id=context.getSharedPreferences("recovery-test",0).getString("id","");JSONObject d=store.draft(id);
                check(!id.isEmpty()&&new File(d.getString("path")).length()==64044&&d.optBoolean("upload_requested"),"local_file_and_queue_survive_force_stop");
                fixture=new FlowInstrumentation();fixture.server();store.base("http://127.0.0.1:"+fixture.server.getLocalPort());
                check(UploadQueue.networkAllowed(context,store),"network_restored");
                main=(MainActivity)startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                long until=SystemClock.elapsedRealtime()+15000;while(store.draft(id).optString("recording_id").isEmpty()){if(SystemClock.elapsedRealtime()>until)throw new IOException("Resume upload timed out");Thread.sleep(100);}
                check(fixture.uploads.get(id)==1&&new File(d.getString("path")).length()==64044,"relaunch_uploads_original_file_once_and_keeps_local_copy");
                final AlertDialog[] options={null};ui(()->options[0]=RecordingOptions.show(main,null));
                try(FileOutputStream out=new FileOutputStream(new File(context.getFilesDir(),"recording-preferences.png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}
                String text=fixture.words(options[0].getWindow().getDecorView());check(text.contains("always saved on this phone")&&text.contains("Automatic cloud processing")&&!text.contains("Keep on phone"),"preferences_explain_unconditional_local_retention");
                ui(()->{((CheckBox)fixture.find(options[0].getWindow().getDecorView(),"Automatic cloud processing")).setChecked(false);((CheckBox)fixture.find(options[0].getWindow().getDecorView(),"Live transcription")).setChecked(false);options[0].getButton(AlertDialog.BUTTON_POSITIVE).performClick();});
                check(store.recordingOptionsSet()&&!store.autoUpload()&&!store.liveDefault(),"recording_preferences_are_remembered");
                until=SystemClock.elapsedRealtime()+10000;while(UploadQueue.running.get()&&SystemClock.elapsedRealtime()<until)Thread.sleep(100);store.deleteDraft(store.draft(id));
            }
            ok=true;
        }catch(Throwable e){try{report.put("failure",e.toString());}catch(Exception ignored){}}
        finally{
            try{if(main!=null)ui(main::finish);if(fixture!=null&&fixture.server!=null)fixture.server.close();report.put("all_passed",ok).put("phase",phase).put("checks",checks);Files.write(new File(context.getFilesDir(),phase+"-recovery-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle b=new Bundle();b.putString("stream",report.toString());finish(ok?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);
        }
    }
}
