package com.teno.app;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.*;

/** Automatic-language UI and outgoing requests, confined to an isolated app and loopback server. */
public final class AutomaticInstrumentation extends Instrumentation {
    final FlowInstrumentation helper=new FlowInstrumentation();
    final Map<String,String> requests=new ConcurrentHashMap<>();
    final JSONArray checks=new JSONArray(),screens=new JSONArray();
    Context context;Store store;MainActivity main;TeamAudioActivity team;AlertDialog options;ServerSocket server;String run;
    interface Condition{boolean value()throws Exception;}
    @Override public void onCreate(Bundle args){super.onCreate(args);run=args.getString("run","normal");start();}
    void check(boolean value,String name)throws Exception{checks.put(helper.json("check",name,"passed",value));if(!value)throw new IOException(name);}
    void ui(Runnable r)throws Exception{runOnMainSync(r);waitForIdleSync();Thread.sleep(180);}
    void until(Condition c)throws Exception{long end=SystemClock.elapsedRealtime()+20000;while(!c.value()){if(SystemClock.elapsedRealtime()>end)throw new IOException("Timed out");Thread.sleep(60);}waitForIdleSync();Thread.sleep(180);}
    void ready(MainActivity a)throws Exception{until(()->!a.loading&&MainActivity.pendingOperations.get()==0);}
    void click(View root,String text)throws Exception{TextView v=helper.find(root,text);check(v!=null&&v.isEnabled(),"action_"+text);ui(v::performClick);}
    int count(View v,Class<?> type){int n=type.isInstance(v)?1:0;if(v instanceof ViewGroup)for(int i=0;i<((ViewGroup)v).getChildCount();i++)n+=count(((ViewGroup)v).getChildAt(i),type);return n;}
    CheckBox consent(View v){if(v instanceof CheckBox)return(CheckBox)v;if(v instanceof ViewGroup)for(int i=0;i<((ViewGroup)v).getChildCount();i++){CheckBox c=consent(((ViewGroup)v).getChildAt(i));if(c!=null)return c;}return null;}
    ScrollView scrolling(View v){if(v instanceof ScrollView)return(ScrollView)v;if(v instanceof ViewGroup)for(int i=0;i<((ViewGroup)v).getChildCount();i++){ScrollView found=scrolling(((ViewGroup)v).getChildAt(i));if(found!=null)return found;}return null;}
    void screen(String name)throws Exception{String file=run+"-"+name+".png";try(FileOutputStream out=new FileOutputStream(new File(context.getFilesDir(),file))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}screens.put(file);}
    void server()throws Exception{
        server=new ServerSocket(0,8,InetAddress.getByName("127.0.0.1"));Thread t=new Thread(()->{while(!server.isClosed())try{Socket s=server.accept();new Thread(()->{try(s){s.setSoTimeout(10000);InputStream in=s.getInputStream();String[] request=helper.line(in).split(" ");Map<String,String> headers=new HashMap<>();String h;while(!(h=helper.line(in)).isEmpty()){int i=h.indexOf(':');headers.put(h.substring(0,i).toLowerCase(Locale.ROOT),h.substring(i+1).trim());}String data=new String(helper.requestBody(in,headers),StandardCharsets.UTF_8);String path=request[1];JSONObject result;int status=200;
            if(!request[0].equals("GET"))requests.put(path,data);
            if(path.equals("/api/v1/recordings")&&request[0].equals("POST"))result=helper.json("recording_id","cloud-auto","job_id","job-auto");
            else if(path.endsWith("/meeting-audio-imports")&&request[0].equals("POST"))result=helper.json("id","import-auto","meeting_id","meeting-auto");
            else if(path.equals("/api/v1/realtime/sessions")){status=503;result=helper.json("code","ASR_BUSY","message","Fixture stops after capturing request");}
            else result=helper.response(path);
            byte[] body=result.toString().getBytes(StandardCharsets.UTF_8);OutputStream out=s.getOutputStream();out.write(("HTTP/1.1 "+status+" Result\r\nContent-Type: application/json\r\nContent-Length: "+body.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));out.write(body);out.flush();
        }catch(Exception ignored){}}).start();}catch(Exception ignored){}});t.setDaemon(true);t.start();
    }
    @Override public void onStart(){boolean passed=false;JSONObject report=new JSONObject();context=getTargetContext();
        try{
            if(!context.getPackageName().equals("com.teno.app.autoverification"))throw new IOException("Isolated package required");
            server();store=new Store(context);store.base("http://127.0.0.1:"+server.getLocalPort());store.identity("Automatic fixture","automatic-"+run);store.tokens(helper.json("access_token","automatic-loopback-fixture"));store.markNativePreferences();store.recordingOptions(false,false,false);
            context.getSharedPreferences("teno",0).edit().putString("language","zh-CN").remove("jwd.last_address").commit();check(store.language().equals("auto"),"old_chinese_preference_becomes_automatic");
            store.language("en-US");check(store.language().equals("auto"),"old_english_preference_becomes_automatic");
            getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.RECORD_AUDIO);if(Build.VERSION.SDK_INT>=33)getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.POST_NOTIFICATIONS);
            main=(MainActivity)startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready(main);
            ui(()->options=RecordingOptions.show(main,null));View form=options.getWindow().getDecorView();check(count(form,Spinner.class)==0&&helper.words(form).contains("Transcription language · Automatic"),"recording_options_have_no_language_picker");screen("01-recording-preferences");if(run.equals("compact")){ui(()->((ScrollView)helper.find(form,"Transcription language · Automatic").getParent().getParent()).scrollTo(0,100000));check(((ScrollView)helper.find(form,"Transcription language · Automatic").getParent().getParent()).getScrollY()>0,"large_text_recording_options_scrolls");screen("01b-recording-preferences-bottom");}ui(options::dismiss);options=null;
            ui(main::preferences);check(count(main.root,Spinner.class)==1&&helper.find(main.root,"Automatic")!=null,"preferences_keep_only_summary_language_picker");check(!helper.words(main.root).contains("Chinese (Mandarin)")&&!helper.words(main.root).contains("English (US)"),"recognition_locale_options_removed");screen("02-preferences");if(run.equals("compact")){ui(()->main.scroll.fullScroll(View.FOCUS_DOWN));screen("02b-preferences-bottom");}click(main.root,"Save preferences");ready(main);check(requests.values().stream().anyMatch(v->v.contains("\"language\":\"auto\"")&&v.contains("\"summary_language\":\"en-US\"")),"saved_preferences_use_auto_and_keep_summary_language");
            store.recordingOptions(false,false,false);ui(main::recordPage);until(()->RecorderService.active);String id=RecorderService.draftId;Thread.sleep(1200);check(RecorderService.capturedBytes>16000&&store.draft(id).optString("language").equals("auto"),"phone_capture_draft_automatic");check(helper.words(main.root).contains("Automatic language detection"),"phone_recording_shows_automatic");screen("03-phone-recording");click(main.root,"Stop and save");until(()->!RecorderService.active&&!RecorderService.finishing&&main.page.equals("local_detail"));
            JSONObject draft=store.draft(id);File audio=new File(draft.getString("path"));check(audio.length()>16044,"automatic_local_save_preserved");draft.put("language","zh-CN");store.save(draft);UploadQueue.enqueue(store,id,false);UploadQueue.resume(context);until(()->!store.draft(id).optString("recording_id").isEmpty());check(requests.get("/api/v1/recordings").contains("name=\"language\"\r\n\r\nauto\r\n"),"old_draft_upload_uses_auto");check(audio.isFile(),"upload_preserves_local_audio");until(()->!UploadQueue.running.get());
            LiveTranscriber live=new LiveTranscriber(store,id,"Automatic probe","zh-CN");try{until(()->requests.containsKey("/api/v1/realtime/sessions"));check(new JSONObject(requests.get("/api/v1/realtime/sessions")).getString("language").equals("auto"),"live_request_uses_auto_even_for_old_locale");}finally{live.close();}
            JSONObject workspace=helper.json("id","visual","name","Product team","membership",helper.json("id","member-1","role","admin"));team=(TeamAudioActivity)startActivitySync(new Intent(context,TeamAudioActivity.class).putExtra("team",workspace.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready(team);ui(()->team.shareConfirmation("Automatic test meeting",Uri.fromFile(audio)));check(count(team.root,Spinner.class)==0&&helper.words(team.root).contains("Speech language · Automatic"),"team_audio_has_no_language_picker");CheckBox consent=consent(team.root);check(consent!=null&&!consent.isChecked(),"team_sharing_still_requires_consent");screen("04-team-import");ui(()->consent.setChecked(true));click(team.root,"Upload to team");until(()->requests.containsKey("/api/v1/teams/visual/meeting-audio-imports")&&!TeamAudioUploadService.active);check(requests.get("/api/v1/teams/visual/meeting-audio-imports").contains("name=\"language\"\r\n\r\nauto\r\n"),"team_upload_uses_auto");
            JSONArray uploads=team.uploads.list("visual");check(uploads.length()==1&&uploads.getJSONObject(0).optString("status").equals("uploaded"),"team_upload_completed");
            // A persisted receipt from an old APK must use the new automatic setting on retry.
            JSONObject receipt=uploads.getJSONObject(0);receipt.put("language","en-US").put("status","failed");team.uploads.save(receipt);requests.remove("/api/v1/teams/visual/meeting-audio-imports");ui(()->team.startUpload(receipt));until(()->requests.containsKey("/api/v1/teams/visual/meeting-audio-imports")&&!TeamAudioUploadService.active);check(requests.get("/api/v1/teams/visual/meeting-audio-imports").contains("name=\"language\"\r\n\r\nauto\r\n"),"old_team_retry_uses_auto");
            passed=true;
        }catch(Throwable e){try{report.put("failure",e.toString());}catch(Exception ignored){}}
        finally{
            try{if(RecorderService.active)context.startService(new Intent(context,RecorderService.class).setAction("stop"));if(options!=null)ui(options::dismiss);if(team!=null)ui(team::finish);if(main!=null)ui(main::finish);if(server!=null)server.close();}catch(Exception ignored){}
            try{report.put("all_passed",passed).put("checks",checks).put("screens",screens).put("scope","Isolated API 35 emulator; real PCM capture; loopback requests; Azure separately verified on server; no physical recorder.");Files.write(new File(context.getFilesDir(),run+"-automatic-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle b=new Bundle();b.putString("stream",report.toString());finish(passed?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);
        }
    }
}
