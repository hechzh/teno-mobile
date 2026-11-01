package com.teno.app;

import android.app.*;
import android.content.*;
import android.os.*;
import android.graphics.Bitmap;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/** Focused final UI and failure-recovery verification; runs in a separate test package. */
public final class V3PolishInstrumentation extends Instrumentation {
    Context c;MainActivity a;Store store;Api api;JSONArray checks=new JSONArray();JSONObject result=new JSONObject();
    interface Condition{boolean ready()throws Exception;}
    void waitFor(Condition test,int seconds)throws Exception{long end=SystemClock.elapsedRealtime()+seconds*1000L;while(!test.ready()){if(SystemClock.elapsedRealtime()>end)throw new IOException("State timed out");Thread.sleep(100);}}
    void check(boolean ok,String name)throws Exception{if(!ok)throw new IOException(name);checks.put(new JSONObject().put("check",name).put("passed",true));Bundle b=new Bundle();b.putString("stream","PASS "+name+"\n");sendStatus(0,b);}
    void ui(Runnable task)throws Exception{runOnMainSync(task);Thread.sleep(200);waitForIdleSync();}
    View find(View v,String label){if(label.equals(String.valueOf(v.getContentDescription())))return v;if(v instanceof ViewGroup)for(int i=0;i<((ViewGroup)v).getChildCount();i++){View found=find(((ViewGroup)v).getChildAt(i),label);if(found!=null)return found;}return null;}
    void shot(String name)throws Exception{Thread.sleep(300);try(FileOutputStream out=new FileOutputStream(new File(c.getFilesDir(),name+".png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}}
    @Override public void onCreate(Bundle args){super.onCreate(args);start();}
    @Override public void onStart(){boolean pass=false;String originalBase="";try{
        c=getTargetContext();store=new Store(c);api=new Api(store);originalBase=store.base();JSONArray accounts=new JSONObject(new String(Files.readAllBytes(new File(c.getFilesDir(),"private-test.json").toPath()),StandardCharsets.UTF_8)).getJSONArray("accounts");for(int i=0;i<accounts.length();i++){JSONObject user=accounts.getJSONObject(i);if(user.optString("username").equals("android_test"))api.login(user.getString("username"),user.getString("password"));}
        api.ensureNativePreferences();check(api.get("/api/v1/me").getJSONObject("settings").optString("summary_language").equals("en-US"),"english_output_default_and_independent_speech_language");
        a=(MainActivity)startActivitySync(new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));waitFor(()->!a.loading,20);
        JSONObject prior=new JSONObject(new String(Files.readAllBytes(new File(c.getFilesDir(),"v3-report.json").toPath()),StandardCharsets.UTF_8));String rid=prior.getString("recording_id");
        JSONObject job=api.post("/api/v1/recordings/"+rid+"/summaries",new JSONObject().put("client_id","v3-polish-english-"+rid));String jid=job.getString("id");waitFor(()->{JSONObject j=api.get("/api/v1/jobs/"+jid);if(j.optString("status").equals("failed"))throw new IOException("Summary job failed");return j.optString("status").equals("completed");},130);
        ui(()->a.detail(rid));waitFor(()->!a.loading,20);String prose=a.currentSummaries.getJSONObject(0).getJSONObject("data").getString("summary");check(!prose.matches("(?s).*[\\p{IsHan}].*"),"real_model_honors_english_summary_preference");shot("15-english-summary");int count=a.currentSummaries.length();ui(a::editSummary);check(find(a.root,"Save new version")!=null,"native_summary_editor_available");ui(()->((EditText)find(a.root,"Summary")).setText("Reviewed Android acceptance summary. The team will prepare a proposal and verify the release."));shot("16-edit-summary");ui(()->find(a.root,"Save new version").performClick());waitFor(()->a.page.equals("detail")&&!a.loading,20);check(a.currentSummaries.length()==count+1&&a.currentSummaries.getJSONObject(0).getJSONObject("data").optBoolean("edited"),"summary_edit_saves_new_version_and_keeps_history");
        ui(()->a.messageDraft("Please review the release report."));ui(()->find(a.root,"Save draft").performClick());check(c.getSharedPreferences("teno",0).getString("message_draft_"+store.scope(),"").contains("release report"),"message_draft_saved_without_sending");shot("17-message-draft");ui(a::preferences);shot("18-preferences");
        String key=JwdProtocol.newKey();store.deviceKey("00:11:22:33:44:66",key);check(new Store(c).deviceKey("00:11:22:33:44:66").equals(key),"device_key_keystore_round_trip_final_build");check(!c.getSharedPreferences("teno",0).getString("jwd.key.00:11:22:33:44:66","").contains(key),"device_key_remains_encrypted");
        store.base("https://127.0.0.1:9");JSONObject draft=store.newDraft("Offline recording acceptance",".wav");draft.put("live",true);store.save(draft);String id=draft.getString("id");ui(()->c.startForegroundService(new Intent(c,RecorderService.class).setAction("start").putExtra("id",id)));waitFor(()->RecorderService.active,8);waitFor(()->RecorderService.live.gap,15);ui(a::showRecorder);check(RecorderService.active&&RecorderService.capturedBytes>0,"network_failure_does_not_stop_local_capture");View stop=find(a.root,"Stop and save");int[] position=new int[2];runOnMainSync(()->stop.getLocationOnScreen(position));check(position[1]+stop.getHeight()<a.getWindow().getDecorView().getHeight(),"stop_control_stays_visible_below_scrolling_transcript");shot("19-offline-recording");ui(()->stop.performClick());waitFor(()->!RecorderService.active&&!RecorderService.finishing,15);JSONObject saved=store.draft(id);check(new File(saved.getString("path")).length()>3200&&!saved.optBoolean("live_complete")&&saved.optString("status").equals("local"),"offline_stop_preserves_audio_for_complete_retranscription");store.base(originalBase);
        JwdActivity recorder=(JwdActivity)startActivitySync(new Intent(c,JwdActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ui(()->find(recorder.getWindow().getDecorView(),"Recorder settings and help").performClick());shot("20-recorder-settings");ui(()->find(recorder.getWindow().getDecorView(),"Buttons and reset").performClick());shot("21-recorder-reset-help");check(!JwdService.active,"reset_help_does_not_send_hardware_commands");ui(recorder::finish);pass=true;
    }catch(Throwable e){try{result.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
    finally{if(!originalBase.isEmpty())store.base(originalBase);if(RecorderService.active)c.startService(new Intent(c,RecorderService.class).setAction("stop"));new File(c.getFilesDir(),"private-test.json").delete();try{result.put("all_passed",pass).put("checks",checks);Files.write(new File(c.getFilesDir(),"v3-polish-report.json").toPath(),result.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}Bundle b=new Bundle();b.putString("stream",result.toString());finish(pass?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);}}
}
