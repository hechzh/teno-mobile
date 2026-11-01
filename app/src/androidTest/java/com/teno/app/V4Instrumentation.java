package com.teno.app;

import android.app.*;
import android.content.*;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;
import android.graphics.Bitmap;
import org.json.*;
import java.io.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;

/** Isolated package and staging backend only; no test classes enter the release APK. */
public final class V4Instrumentation extends Instrumentation {
    Context context;TeamAudioActivity activity;Store store;Api api;JSONArray checks=new JSONArray();JSONObject report=new JSONObject();
    interface Condition{boolean ready()throws Exception;}
    void waitFor(Condition c,int seconds)throws Exception{long until=SystemClock.elapsedRealtime()+seconds*1000L;while(!c.ready()){if(SystemClock.elapsedRealtime()>until)throw new IOException("Timed out waiting for test state");Thread.sleep(150);}}
    void check(boolean ok,String name)throws Exception{if(!ok)throw new IOException(name);checks.put(new JSONObject().put("check",name).put("passed",true));Bundle b=new Bundle();b.putString("stream","PASS "+name+"\n");sendStatus(0,b);}
    void ui(Runnable r)throws Exception{runOnMainSync(r);Thread.sleep(150);waitForIdleSync();}
    View find(View v,String text){if(v instanceof TextView&&((TextView)v).getText().toString().equals(text))return v;if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++){View found=find(g.getChildAt(i),text);if(found!=null)return found;}}return null;}
    CheckBox checkbox(View v){if(v instanceof CheckBox)return (CheckBox)v;if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++){CheckBox b=checkbox(g.getChildAt(i));if(b!=null)return b;}}return null;}
    void screenshot(String name)throws Exception{Thread.sleep(350);try(FileOutputStream out=new FileOutputStream(new File(context.getFilesDir(),name+".png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}}
    @Override public void onCreate(Bundle args){super.onCreate(args);start();}
    @Override public void onStart(){context=getTargetContext();store=new Store(context);api=new Api(store);boolean ok=false;
        try{
            check(context.getPackageName().equals("com.teno.app.v4verification"),"isolated_test_package");
            JSONObject config=new JSONObject(new String(Files.readAllBytes(new File(context.getFilesDir(),"private-test.json").toPath()),StandardCharsets.UTF_8));JSONObject account=null;JSONArray accounts=config.getJSONArray("accounts");for(int i=0;i<accounts.length();i++)if(accounts.getJSONObject(i).getString("username").equals("android_test"))account=accounts.getJSONObject(i);
            store.base("http://10.0.2.2:18012");api.login(account.getString("username"),account.getString("password"));
            JSONObject caps=api.get("/api/v1/capabilities");check(caps.getInt("max_audio_seconds")==7200&&caps.getLong("max_upload_bytes")==262144000&&caps.getInt("phone_recording_max_seconds")==3240,"server_limits_120_minutes_250_MiB_phone_54_minutes");
            JSONArray teams=api.get("/api/v1/team-auth/me").getJSONArray("teams");JSONObject team=null;for(int i=0;i<teams.length();i++)if(teams.getJSONObject(i).optString("name").equals("Teno audio acceptance"))team=teams.getJSONObject(i);check(team!=null,"authenticated_team_workspace_available");
            activity=(TeamAudioActivity)startActivitySync(new Intent(context,TeamAudioActivity.class).putExtra("team",team.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));waitFor(()->!activity.loading&&activity.uploads!=null,30);screenshot("01-audio-imports");
            check(find(activity.root,"Import audio file")!=null&&find(activity.root,"Import from my library")!=null,"file_phone_JWD_and_personal_library_entries");
            File source=new File(context.getFilesDir(),"acceptance.wav");check(source.isFile(),"synthetic_audio_fixture_available");
            ui(()->activity.shareConfirmation("Teno Android 0.4 acceptance",Uri.fromFile(source)));
            check(checkbox(activity.root)!=null&&!checkbox(activity.root).isChecked(),"team_audio_requires_explicit_sharing_consent");screenshot("02-team-sharing-consent");
            ui(()->{checkbox(activity.root).setChecked(true);find(activity.root,"Upload to team").performClick();});
            waitFor(()->activity.uploads.list(activity.teamId).length()>0,20);
            JSONObject receipt=activity.uploads.list(activity.teamId).getJSONObject(0);String uploadId=receipt.getString("id");
            waitFor(()->activity.uploads.load(uploadId).optString("status").equals("uploaded")||activity.uploads.load(uploadId).optString("status").equals("failed"),120);
            receipt=activity.uploads.load(uploadId);check(receipt.optString("status").equals("uploaded"),"foreground_streaming_upload_returns_persistent_receipt");
            check(source.isFile()&&new File(receipt.getString("path")).isFile(),"original_audio_and_retry_copy_retained");
            String mid=receipt.getString("meeting_id"),prefix="/api/v1/teams/"+team.getString("id");
            waitFor(()->api.get(prefix+"/meetings/"+mid).optJSONObject("transcript")!=null,120);
            ui(()->activity.openAudio(mid));waitFor(()->!activity.loading,25);screenshot("03-speaker-review");
            JSONObject current=api.get(prefix+"/meetings/"+mid);check(current.getJSONObject("audio").optBoolean("ready"),"team_audio_playback_available");
            ui(()->activity.playSegment(500));waitFor(()->activity.playerReady,25);check(activity.player!=null&&activity.player.getDuration()>3000,"authenticated_audio_prepares_and_seeks");screenshot("04-audio-playback");ui(()->{activity.releasePlayer();if(activity.dialog!=null)activity.dialog.dismiss();});
            String label=current.getJSONObject("transcript").getJSONArray("segments").getJSONObject(0).getString("speaker_label");
            JSONObject body=new JSONObject().put("version",current.getInt("version")).put("bindings",new JSONObject().put(label,JSONObject.NULL)).put("external_labels",new JSONArray().put(label));
            JSONObject saved=api.request("PUT",prefix+"/meetings/"+mid+"/speakers",body);check(saved.getInt("revision")>current.getInt("revision"),"manual_speaker_review_creates_new_identity_revision");
            JSONObject old=api.get(prefix+"/meetings/"+mid+"?revision="+current.getInt("revision"));check(!old.getJSONObject("identity_review").optBoolean("can_publish"),"historical_identity_snapshot_is_preserved");
            ui(()->activity.openAudio(mid));waitFor(()->!activity.loading,20);check(find(activity.root,"Confirmed external speaker")!=null,"external_speaker_does_not_require_team_member");screenshot("05-confirmed-external-speaker");
            ui(activity::profiles);waitFor(()->!activity.loading,20);check(find(activity.root,"Create a member profile")!=null,"administrator_voice_profile_controls");screenshot("06-voice-profiles");
            JSONObject profile=api.post(prefix+"/voice-profiles",new JSONObject().put("member_id",team.getJSONObject("membership").getString("id")));check(profile.getString("status").equals("incomplete"),"new_voice_profile_is_not_automatically_activated");
            api.request("DELETE",prefix+"/voice-profiles/"+profile.getString("id"),null);check(true,"profile_revocation_endpoint");
            TeamActivity parent=(TeamActivity)startActivitySync(new Intent(context,TeamActivity.class).putExtra("team",team.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));waitFor(()->!parent.loading,25);ui(()->parent.openMeeting(mid,""));waitFor(()->!parent.loading,25);View publish=find(parent.root,"Review and publish");check(publish==null||!publish.isEnabled(),"publish_disabled_for_unreviewed_or_outdated_identity_version");screenshot("07-publish-gate");ui(parent::finish);
            report.put("meeting_id",mid);ok=true;
        }catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        finally{new File(context.getFilesDir(),"private-test.json").delete();try{report.put("all_passed",ok).put("checks",checks).put("android_api",Build.VERSION.SDK_INT).put("scope","API 35 emulator with synthetic audio and isolated staging backend; physical Magic4 Pro and JWD remain unverified");Files.write(new File(context.getFilesDir(),"v4-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}Bundle result=new Bundle();result.putString("stream",report.toString());finish(ok?Activity.RESULT_OK:Activity.RESULT_CANCELED,result);}
    }
}
