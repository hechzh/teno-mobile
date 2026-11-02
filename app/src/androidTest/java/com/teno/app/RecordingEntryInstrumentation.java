package com.teno.app;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/** Isolated entry-routing checks. Device states are UI fixtures, never BLE evidence. */
public final class RecordingEntryInstrumentation extends Instrumentation {
    Context context; MainActivity main; JwdActivity device; Store store;
    NavigationInstrumentation fixture; String runName,createdDraft="";
    final JSONArray checks=new JSONArray(),screens=new JSONArray();
    @Override public void onCreate(Bundle args){super.onCreate(args);runName=args.getString("run","normal");start();}
    void check(boolean ok,String name)throws Exception{checks.put(new JSONObject().put("check",name).put("passed",ok));if(!ok)throw new IOException(name);}
    void ui(Runnable action)throws Exception{runOnMainSync(action);waitForIdleSync();Thread.sleep(200);}
    interface Condition{boolean ready();}
    void until(Condition condition)throws Exception{long limit=SystemClock.elapsedRealtime()+10000;while(!condition.ready()){if(SystemClock.elapsedRealtime()>limit)throw new IOException("Timed out");Thread.sleep(80);}waitForIdleSync();Thread.sleep(200);}
    void ready()throws Exception{until(()->!main.loading&&MainActivity.pendingOperations.get()==0);}
    TextView find(View root,String value){if(root instanceof TextView&&((TextView)root).getText().toString().equals(value))return(TextView)root;if(root instanceof ViewGroup){ViewGroup parent=(ViewGroup)root;for(int i=0;i<parent.getChildCount();i++){TextView found=find(parent.getChildAt(i),value);if(found!=null)return found;}}return null;}
    String text(View view){String value=view instanceof TextView?((TextView)view).getText().toString()+"\n":"";if(view instanceof ViewGroup){ViewGroup g=(ViewGroup)view;for(int i=0;i<g.getChildCount();i++)value+=text(g.getChildAt(i));}return value;}
    int spinners(View view){int count=view instanceof Spinner?1:0;if(view instanceof ViewGroup){ViewGroup g=(ViewGroup)view;for(int i=0;i<g.getChildCount();i++)count+=spinners(g.getChildAt(i));}return count;}
    void click(View root,String value)throws Exception{TextView item=find(root,value);check(item!=null&&item.isEnabled(),"click_available_"+value);ui(item::performClick);}
    void screen(String name)throws Exception{String file=runName+"-"+name+".png";try(FileOutputStream out=new FileOutputStream(new File(context.getFilesDir(),file))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}screens.put(file);}
    void openDevice(Runnable action)throws Exception{ActivityMonitor monitor=addMonitor(JwdActivity.class.getName(),null,false);ui(action);Activity activity=waitForMonitorWithTimeout(monitor,5000);removeMonitor(monitor);check(activity instanceof JwdActivity,"hardware_entry_opens_recorder_screen");device=(JwdActivity)activity;waitForIdleSync();Thread.sleep(300);}
    void closeDevice()throws Exception{if(device!=null){JwdActivity current=device;ui(current::finish);device=null;ready();}}
    void deviceState(boolean authorized,int recording)throws Exception{
        JwdService.snapshot=new JSONObject().put("name","Layout fixture recorder").put("connected",true).put("authorized",authorized).put("busy",!authorized).put("record_state",recording).put("record_start",SystemClock.elapsedRealtime()).put("message",authorized?"Layout fixture: device ready":"Layout fixture: authorizing").toString();
        Thread.sleep(1100);waitForIdleSync();
    }
    void inspectEntryHierarchy()throws Exception{
        TextView primary=find(main.root,"Record with device"),phone=find(main.root,"Record with phone");
        check(primary instanceof Button&&phone!=null&&!(phone instanceof Button),"recorder_primary_phone_text_link");
        check(phone.getTextSize()<primary.getTextSize()&&phone.getHeight()>=main.dp(48),"phone_link_smaller_text_accessible_tap_height");
        int[] first=new int[2],second=new int[2];primary.getLocationOnScreen(first);phone.getLocationOnScreen(second);
        check(first[1]+primary.getHeight()<=second[1],"phone_link_below_recorder_button");
        check(primary.getLineCount()==1&&phone.getLineCount()==1,"entry_labels_fit_single_line");
        check(find(main.root,"Start recording")==null,"no_ambiguous_phone_primary_on_home");
    }
    @Override public void onStart(){
        JSONObject report=new JSONObject();boolean ok=false;context=getTargetContext();
        try{
            if(!context.getPackageName().equals("com.teno.app.recordentryverification"))throw new IOException("Isolated application required");
            check(!RecorderService.active&&!JwdService.active,"no_initial_recording_or_bluetooth_service");
            check(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_DENIED,"initial_microphone_permission_denied");
            fixture=new NavigationInstrumentation();fixture.startFixture();store=new Store(context);store.base("http://127.0.0.1:"+fixture.server.getLocalPort());store.identity("Layout review","layout-fixture");store.markNativePreferences();store.tokens(new JSONObject().put("access_token","local-fixture-only"));context.getSharedPreferences("teno",0).edit().putBoolean("live_default",false).apply();JwdService.snapshot="{}";
            main=(MainActivity)startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready();inspectEntryHierarchy();screen("01-library");
            openDevice(()->find(main.root,"Record with device").performClick());
            check(find(device.getWindow().getDecorView(),"Connect your recorder")!=null,"unconnected_entry_requests_recorder_connection");
            check(find(device.getWindow().getDecorView(),"Scan for devices")!=null,"scanner_available_without_phone_fallback");
            check(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_DENIED&&!RecorderService.active,"hardware_entry_does_not_request_or_start_microphone");screen("02-connect-recorder");
            deviceState(false,0);check(!find(device.getWindow().getDecorView(),"Start recording").isEnabled(),"unverified_connection_cannot_start");screen("03-authorizing-fixture");
            deviceState(true,0);check(find(device.getWindow().getDecorView(),"Start recording").isEnabled(),"authorized_idle_recorder_has_start_action");screen("04-connected-fixture");
            deviceState(true,1);click(device.getWindow().getDecorView(),"Open recording");check(find(device.getWindow().getDecorView(),"Recording on device")!=null,"existing_hardware_recording_opens_device_view");check(!RecorderService.active&&!JwdService.active,"fixture_states_do_not_start_real_services");screen("05-device-recording-fixture");closeDevice();JwdService.snapshot="{}";
            ui(main::addContent);AlertDialog menu=(AlertDialog)main.dialog;ListView list=menu.getListView();check(list.getAdapter().getItem(0).equals("Record with device")&&list.getAdapter().getItem(3).equals("Record with phone"),"add_menu_device_first_phone_explicit");screen("06-add-menu");
            openDevice(()->list.performItemClick(list.getChildAt(0),0,list.getAdapter().getItemId(0)));closeDevice();
            getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.RECORD_AUDIO);if(Build.VERSION.SDK_INT>=33)getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.POST_NOTIFICATIONS);
            ui(main::home);ready();click(main.root,"Record with phone");
            check(main.page.equals("setup")&&text(main.root).contains("Phone microphone"),"phone_link_opens_phone_only_setup");
            check(spinners(main.root)==1&&!text(main.root).contains("Audio source"),"phone_setup_has_no_ambiguous_source_selector");screen("07-phone-setup");
            ui(main::home);ready();ui(main::addContent);AlertDialog phoneMenu=(AlertDialog)main.dialog;ListView phoneList=phoneMenu.getListView();ui(()->phoneList.performItemClick(phoneList.getChildAt(3),3,phoneList.getAdapter().getItemId(3)));check(main.page.equals("setup"),"add_menu_phone_choice_opens_phone_setup");
            click(main.root,"Start phone recording");until(()->RecorderService.active);createdDraft=RecorderService.draftId;Thread.sleep(1200);check(RecorderService.capturedBytes>16000,"explicit_phone_action_captures_pcm_locally");until(()->main.page.equals("record"));screen("08-phone-recording");
            ui(main::home);ready();check(find(main.root,"Record with device")!=null&&find(main.root,"Return to phone recording")!=null,"active_phone_recording_keeps_device_primary_and_return_link");screen("09-phone-active-library");click(main.root,"Return to phone recording");check(main.page.equals("record")&&createdDraft.equals(RecorderService.draftId),"phone_return_reuses_current_recording");
            click(main.root,"Stop and save");until(()->!RecorderService.active&&!RecorderService.finishing);until(()->main.page.equals("save"));JSONObject saved=store.draft(createdDraft);byte[] wav=Files.readAllBytes(new File(saved.getString("path")).toPath());
            check(wav.length>32044&&ByteBuffer.wrap(wav,40,4).order(ByteOrder.LITTLE_ENDIAN).getInt()==wav.length-44,"explicit_phone_recording_saves_complete_wav");check(saved.optString("recording_id").isEmpty(),"phone_audio_not_uploaded_automatically");screen("10-phone-saved");ok=true;
        }catch(Throwable error){try{report.put("failure",error.toString());}catch(Exception ignored){}}
        finally{
            try{if(RecorderService.active||RecorderService.finishing){context.startService(new Intent(context,RecorderService.class).setAction("stop"));until(()->!RecorderService.active&&!RecorderService.finishing);}closeDevice();if(main!=null)ui(main::finish);if(!createdDraft.isEmpty()&&store!=null)store.deleteDraft(store.draft(createdDraft));}catch(Exception ignored){}
            JwdService.snapshot="{}";if(fixture!=null&&fixture.server!=null)try{fixture.server.close();}catch(Exception ignored){}
            try{report.put("all_passed",ok).put("checks",checks).put("screens",screens).put("scope","API 35 emulator; read-only loopback data; device UI states are synthetic. Actual local phone capture; no real BLE, cloud or physical-device acceptance.");Files.write(new File(context.getFilesDir(),runName+"-recording-entry-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle result=new Bundle();result.putString("stream",report.toString());finish(ok?Activity.RESULT_OK:Activity.RESULT_CANCELED,result);
        }
    }
}
