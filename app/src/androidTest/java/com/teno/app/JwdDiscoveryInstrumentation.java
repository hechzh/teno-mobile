package com.teno.app;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/** Synthetic discovery rows are confined to this explicit test runner, never the release APK. */
public final class JwdDiscoveryInstrumentation extends Instrumentation {
    private final JSONArray checks=new JSONArray();private final JSONObject report=new JSONObject();
    private void check(boolean ok,String name)throws Exception{if(!ok)throw new IOException(name);checks.put(new JSONObject().put("check",name).put("passed",true));}
    private View find(View view,String text){if(view instanceof TextView&&((TextView)view).getText().toString().equals(text))return view;if(view instanceof ViewGroup){ViewGroup g=(ViewGroup)view;for(int i=0;i<g.getChildCount();i++){View v=find(g.getChildAt(i),text);if(v!=null)return v;}}return null;}
    private void click(Activity a,String text){View v=find(a.getWindow().getDecorView(),text);if(v==null)throw new IllegalStateException("Missing control: "+text);v.performClick();}
    @Override public void onCreate(Bundle args){super.onCreate(args);start();}
    @Override public void onStart(){
        Context c=getTargetContext();JwdActivity activity=null;String previous=JwdService.snapshot;boolean success=false;
        try{
            JSONObject unknown=new JSONObject().put("name","SGMf91a73").put("address","C0:00:00:00:00:21").put("gatt_status","unknown").put("rssi",-40);
            JSONObject named=new JSONObject().put("name","VTR7900_P_TEST").put("address","C0:00:00:00:00:22").put("gatt_status","unknown").put("rssi",-50);
            JSONObject advertised=new JSONObject().put("name","Custom_TEST").put("address","C0:00:00:00:00:23").put("gatt_status","unknown").put("jwd",true).put("rssi",-60);
            JSONObject verified=new JSONObject().put("name","Verified_TEST").put("address","C0:00:00:00:00:24").put("gatt_status","verified").put("rssi",-70);
            check(JwdActivity.deviceRank(unknown)==3,"unrecognized_name_not_presented_as_jwd");
            check(JwdActivity.deviceRank(named)==2&&JwdActivity.deviceEvidence(named).contains("待检查"),"vendor_name_remains_unverified_hint");
            check(JwdActivity.deviceRank(advertised)==1&&JwdActivity.deviceEvidence(advertised).contains("待连接核实"),"advertisement_not_claimed_as_gatt_verification");
            check(JwdActivity.deviceRank(verified)==0,"gatt_verification_highest_priority");
            JSONObject incomplete=new JSONObject(advertised.toString()).put("gatt_status","unsupported");check(JwdActivity.deviceRank(incomplete)==3,"failed_gatt_check_overrides_advertisement");
            JwdService.snapshot=new JSONObject().put("message","自动测试场景：以下条目为测试数据").put("devices",new JSONArray().put(unknown).put(named).put(advertised).put(verified)).toString();
            activity=(JwdActivity)startActivitySync(new Intent(c,JwdActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));JwdActivity a=activity;Thread.sleep(500);
            check(find(a.getWindow().getDecorView(),"SGMf91a73")==null,"unknown_devices_collapsed_by_default");
            check(find(a.getWindow().getDecorView(),"连接录音卡：VTR7900_P_TEST")==null&&find(a.getWindow().getDecorView(),"检查 JWD 服务：VTR7900_P_TEST")!=null,"unverified_device_only_offers_probe");
            check(find(a.getWindow().getDecorView(),"连接录音卡：Verified_TEST")!=null,"verified_device_offers_connect");
            runOnMainSync(()->click(a,"展开其他未识别设备（1）"));check(find(a.getWindow().getDecorView(),"检查 JWD 服务：SGMf91a73")!=null,"unknown_model_can_still_be_probed");
            try(FileOutputStream out=new FileOutputStream(new File(c.getFilesDir(),"jwd-discovery-fixture.png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}
            getUiAutomation().grantRuntimePermission(c.getPackageName(),Manifest.permission.BLUETOOTH_SCAN);getUiAutomation().grantRuntimePermission(c.getPackageName(),Manifest.permission.BLUETOOTH_CONNECT);
            runOnMainSync(()->click(a,"检查 JWD 服务：SGMf91a73"));Thread.sleep(800);
            check(new Store(c).deviceKey("C0:00:00:00:00:21").isEmpty(),"probe_never_creates_device_binding_key");
            JSONObject state=new JSONObject(JwdService.snapshot);check(!state.optBoolean("authorized")&&!state.optBoolean("connected"),"probe_does_not_claim_authorized_connection");
            check(state.has("system_pairing_requested")&&state.has("system_pairing_stage")&&state.has("jwd_service_verified"),"diagnostics_include_pairing_stage_and_service_evidence");
            runOnMainSync(()->c.startForegroundService(new Intent(c,JwdService.class).setAction("disconnect")));Thread.sleep(500);check(!JwdService.active,"probe_disconnect_releases_service");
            runOnMainSync(()->c.startForegroundService(new Intent(c,JwdService.class).setAction("scan_compat")));Thread.sleep(700);
            state=new JSONObject(JwdService.snapshot);check(JwdService.active&&state.optBoolean("scanning")&&state.optBoolean("compatibility_scan"),"vendor_compatible_discovery_starts");
            runOnMainSync(()->c.startForegroundService(new Intent(c,JwdService.class).setAction("disconnect")));Thread.sleep(500);check(!JwdService.active,"compatible_discovery_stops_with_service");success=true;
        }catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        finally{
            if(activity!=null){JwdActivity a=activity;runOnMainSync(a::finish);}JwdService.snapshot=previous;
            try{report.put("all_passed",success).put("checks",checks).put("android_api",Build.VERSION.SDK_INT).put("scope","Synthetic discovery UI evidence and emulator service lifecycle only. No physical GATT or PIN pairing verified.");Files.write(new File(c.getFilesDir(),"jwd-discovery-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle b=new Bundle();b.putString("stream",report.toString());finish(success?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);
        }
    }
}
