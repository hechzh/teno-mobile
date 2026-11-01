package com.teno.app;

import android.app.*;
import android.content.*;
import android.media.MediaMetadataRetriever;
import android.os.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;

/** Explicitly invoked acceptance runner. Inputs are pushed privately via adb, never packaged. */
public final class SmokeInstrumentation extends Instrumentation {
    private final JSONArray checks=new JSONArray();
    private JSONObject report=new JSONObject();
    private MainActivity activity;
    private String mode="full";
    private void pass(String name)throws Exception{checks.put(new JSONObject().put("check",name).put("passed",true));Bundle b=new Bundle();b.putString("stream",name+" PASS\n");sendStatus(0,b);}
    private void require(boolean test,String reason)throws Exception{if(!test)throw new IOException(reason);}
    @Override public void onCreate(Bundle args){super.onCreate(args);if(args!=null)mode=args.getString("mode","full");start();}
    @Override public void onStart(){
        if(mode.equals("ui")){uiChecks();return;}
        Context c=getTargetContext();Store store=new Store(c);Api api=new Api(store);boolean success=false;
        try{
            JSONObject account=new JSONObject(new String(Files.readAllBytes(new File(c.getFilesDir(),"private-test.json").toPath()),StandardCharsets.UTF_8));
            require(Api.validateBase(Store.DEFAULT_URL).startsWith("https://"),"HTTPS default");
            require(api.get("/health/ready").optString("status").equals("ready"),"HTTPS health");pass("https_trusted_certificate");
            api.login(account.getString("username"),account.getString("password"));require(!store.token("access_token").isEmpty(),"Login persistence");pass("login_keystore_session");
            activity=(MainActivity)startActivitySync(new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));Thread.sleep(2000);
            JSONObject recorded=store.newDraft("Teno 麦克风采集验收（模拟器）",".m4a");store.save(recorded);
            final String recordedId=recorded.getString("id");
            runOnMainSync(()->c.startForegroundService(new Intent(c,RecorderService.class).setAction("start").putExtra("id",recordedId)));
            Thread.sleep(2500);require(RecorderService.active,"Recorder must be active");
            runOnMainSync(()->activity.showRecorder());Thread.sleep(500);screenshot(c,"recording.png");
            runOnMainSync(()->c.startService(new Intent(c,RecorderService.class).setAction("pause")));Thread.sleep(400);require(RecorderService.paused,"Pause must work");
            runOnMainSync(()->c.startService(new Intent(c,RecorderService.class).setAction("pause")));Thread.sleep(1000);require(!RecorderService.paused,"Resume must work");
            runOnMainSync(()->c.startService(new Intent(c,RecorderService.class).setAction("stop")));Thread.sleep(1200);require(!RecorderService.active,"Recording stopped");
            MediaMetadataRetriever reader=new MediaMetadataRetriever();reader.setDataSource(recorded.getString("path"));require(Long.parseLong(reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION))>1000,"Valid captured duration");reader.release();pass("microphone_pause_resume_saved_m4a");
            for(int i=0;i<60&&TransferService.active;i++)Thread.sleep(1000);
            recorded=store.draft(recorded.getString("id"));require(!recorded.optString("recording_id").isEmpty(),"Recorded audio automatically uploaded");pass("recording_auto_upload_service");
            JSONObject draft=store.newDraft("Teno 会议链路验收",".wav");
            draft.put("language","en-US");require(new File(c.getFilesDir(),"acceptance.wav").length()>400000,"Spoken fixture must be intact");
            Files.copy(new File(c.getFilesDir(),"acceptance.wav").toPath(),new File(draft.getString("path")).toPath());store.save(draft);
            final String draftId=draft.getString("id");
            runOnMainSync(()->c.startForegroundService(new Intent(c,TransferService.class).putExtra("id",draftId)));
            Thread.sleep(700);for(int i=0;i<90&&TransferService.active;i++)Thread.sleep(1000);
            draft=store.draft(draft.getString("id"));String rid=draft.optString("recording_id");require(!rid.isEmpty(),draft.optString("error","Upload failed"));report.put("recording_id",rid);pass("spoken_fixture_android_upload");
            waitJob(api,draft.getString("job_id"));JSONObject trans=api.get("/api/v1/recordings/"+rid+"/transcriptions");require(trans.getJSONArray("segments").length()>0,"Speech transcript missing");report.put("transcript",trans);pass("azure_transcription_from_android");
            JSONArray summaries=new JSONArray();for(int i=0;i<90;i++){summaries=api.get("/api/v1/recordings/"+rid+"/summaries").getJSONArray("items");if(summaries.length()>0)break;Thread.sleep(2000);}require(summaries.length()>0,"Summary missing");report.put("summary",summaries.getJSONObject(0));pass("automatic_deepseek_summary");
            JSONObject chat=api.post("/api/v1/chats",new JSONObject().put("title","Teno 安卓问答验收").put("recording_ids",new JSONArray().put(rid)));
            JSONObject q=api.post("/api/v1/chats/"+chat.getString("id")+"/messages",new JSONObject().put("question","Who will prepare the proposal?").put("client_id",UUID.randomUUID().toString()));JSONObject answer=waitJob(api,q.getString("id"));require(answer.getJSONObject("result").getJSONArray("citations").length()>0,"Citations missing");pass("qa_with_source_citations");
            JSONObject folder=api.post("/api/v1/folders",new JSONObject().put("title","Teno Android 测试"));api.request("PATCH","/api/v1/recordings/"+rid,new JSONObject().put("folder_id",folder.getString("id")));require(api.get("/api/v1/recordings?folder_id="+folder.getString("id")).getJSONArray("items").length()>0,"Folder filter");pass("folder_metadata_and_filter");
            JSONObject todo=api.post("/api/v1/tasks",new JSONObject().put("title","核对安卓内测反馈"));api.request("PATCH","/api/v1/tasks/"+todo.getString("id"),new JSONObject().put("completed",true));require(api.get("/api/v1/tasks/"+todo.getString("id")).getJSONObject("data").getBoolean("completed"),"Task completion");pass("task_create_complete");
            require(api.bytes("GET","/api/v1/recordings/"+rid+"/exports?format=md",null).length>10,"Export missing");pass("export_markdown");
            runOnMainSync(()->activity.detail(rid));Thread.sleep(3500);require(activity.currentSummaries.length()>0,"Summary screen did not display server result");pass("summary_rendered_in_activity");
            screenshot(c,"summary.png");runOnMainSync(()->activity.home());Thread.sleep(2500);screenshot(c,"home.png");
            success=true;
        }catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        finally{
            try{report.put("checks",checks).put("all_passed",success).put("android_api",Build.VERSION.SDK_INT).put("microphone_note","Emulator microphone capture validates recording, pause/resume and upload. Spoken speech is a separate synthetic WAV fixture, not a physical-device microphone quality test.");Files.write(new File(c.getFilesDir(),"acceptance-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));new File(c.getFilesDir(),"private-test.json").delete();}catch(Exception ignored){}
            Bundle result=new Bundle();result.putString("stream",report.toString());finish(success?Activity.RESULT_OK:Activity.RESULT_CANCELED,result);
        }
    }
    JSONObject waitJob(Api api,String id)throws Exception{for(int i=0;i<120;i++){JSONObject j=api.get("/api/v1/jobs/"+id);if(j.optString("status").equals("completed"))return j;if(j.optString("status").equals("failed"))throw new IOException(j.optJSONObject("error").toString());Thread.sleep(2000);}throw new IOException("Job timeout");}
    void screenshot(Context c,String name)throws Exception{android.graphics.Bitmap bitmap=getUiAutomation().takeScreenshot();try(FileOutputStream f=new FileOutputStream(new File(c.getFilesDir(),name))){bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,f);}}
    void uiChecks(){
        Context c=getTargetContext();Api api=new Api(new Store(c));boolean success=false;
        try{
            JSONObject original=new JSONObject(new String(Files.readAllBytes(new File(c.getFilesDir(),"acceptance-report.json").toPath()),StandardCharsets.UTF_8));String rid=original.getString("recording_id");
            activity=(MainActivity)startActivitySync(new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));Thread.sleep(2000);
            runOnMainSync(()->activity.localStorage());Thread.sleep(300);require(activity.content.getChildCount()>1,"Local storage rows missing");pass("local_storage_screen");
            runOnMainSync(()->activity.resources("events"));Thread.sleep(1000);runOnMainSync(()->activity.docEditor("events",null));Thread.sleep(300);
            runOnMainSync(()->{
                java.util.List<android.widget.EditText> fields=new java.util.ArrayList<>();collect(activity.dialog.getWindow().getDecorView(),fields);
                fields.get(0).setText("Teno UI 日程验收");fields.get(1).setText("界面保存测试");fields.get(2).setText("2026-11-01 10:00");fields.get(3).setText("2026-11-01 11:00");
                ((AlertDialog)activity.dialog).getButton(AlertDialog.BUTTON_POSITIVE).performClick();
            });Thread.sleep(2000);
            JSONArray events=api.get("/api/v1/events").getJSONArray("items");boolean found=false;for(int i=0;i<events.length();i++)if(events.getJSONObject(i).getJSONObject("data").optString("title").equals("Teno UI 日程验收"))found=true;require(found,"Event form did not save");pass("calendar_form_real_save");
            runOnMainSync(()->activity.detail(rid));Thread.sleep(2000);runOnMainSync(()->activity.playCloud(rid,0));
            boolean played=false;for(int i=0;i<60;i++){Thread.sleep(500);if(activity.player!=null&&activity.playerReady&&activity.player.isPlaying()){played=true;break;}}
            require(played,"HTTPS audio playback was not ready within 30 seconds");pass("https_audio_playback");
            runOnMainSync(()->activity.releasePlayer());
            JSONObject job=api.post("/api/v1/recordings/"+rid+"/mindmap",new JSONObject());waitJob(api,job.getString("id"));
            runOnMainSync(()->{activity.detailTab="导图";activity.renderDetail();});Thread.sleep(2500);screenshot(c,"mindmap.png");pass("mindmap_render");
            runOnMainSync(()->activity.resources("memories"));Thread.sleep(1500);screenshot(c,"memories.png");pass("memory_screen");
            runOnMainSync(()->activity.settings());Thread.sleep(500);screenshot(c,"settings.png");pass("settings_screen");
            success=true;
        }catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        try{report.put("checks",checks).put("all_passed",success);Files.write(new File(c.getFilesDir(),"ui-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
        Bundle result=new Bundle();result.putString("stream",report.toString());finish(success?Activity.RESULT_OK:Activity.RESULT_CANCELED,result);
    }
    void collect(android.view.View view,java.util.List<android.widget.EditText> fields){if(view instanceof android.widget.EditText)fields.add((android.widget.EditText)view);if(view instanceof android.view.ViewGroup){android.view.ViewGroup group=(android.view.ViewGroup)view;for(int i=0;i<group.getChildCount();i++)collect(group.getChildAt(i),fields);}}
}
