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
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class JwdUiInstrumentation extends Instrumentation {
    private final JSONArray checks=new JSONArray();private final JSONObject report=new JSONObject();
    void pass(String name)throws Exception{checks.put(new JSONObject().put("check",name).put("passed",true));}
    void require(boolean ok,String message)throws IOException{if(!ok)throw new IOException(message);}
    void click(View view,String label){
        if(view instanceof TextView&&((TextView)view).getText().toString().equals(label)){view.performClick();return;}
        if(view instanceof ViewGroup){ViewGroup g=(ViewGroup)view;for(int i=0;i<g.getChildCount();i++)click(g.getChildAt(i),label);}
    }
    @Override public void onCreate(Bundle args){super.onCreate(args);start();}
    @Override public void onStart(){
        boolean success=false;Context c=getTargetContext();JwdActivity activity=null;
        try{
            activity=(JwdActivity)startActivitySync(new Intent(c,JwdActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));JwdActivity a=activity;Thread.sleep(500);
            require(c.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_DENIED,"Fresh verification app must lack scan permission");
            runOnMainSync(()->a.onRequestPermissionsResult(31,new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT},new int[]{PackageManager.PERMISSION_DENIED,PackageManager.PERMISSION_DENIED}));
            Thread.sleep(300);require(!JwdService.active,"Denied permission must not start service");pass("permission_denial_does_not_connect");
            runOnMainSync(a::finish);Thread.sleep(300);
            getUiAutomation().grantRuntimePermission(c.getPackageName(),Manifest.permission.BLUETOOTH_SCAN);getUiAutomation().grantRuntimePermission(c.getPackageName(),Manifest.permission.BLUETOOTH_CONNECT);
            activity=(JwdActivity)startActivitySync(new Intent(c,JwdActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));JwdActivity b=activity;
            runOnMainSync(()->click(b.getWindow().getDecorView(),"扫描附近设备"));Thread.sleep(1200);
            require(JwdService.active,"Foreground BLE service should start");require(new JSONObject(JwdService.snapshot).optBoolean("scanning"),"BLE scan must run");pass("granted_permissions_start_real_scan");
            Thread.sleep(15000);JSONObject snapshot=new JSONObject(JwdService.snapshot);require(!snapshot.optBoolean("scanning"),"Scan must be bounded");require(!snapshot.optBoolean("connected")&&!snapshot.optBoolean("authorized"),"No hardware connected");pass("bounded_scan_no_fabricated_connection");
            try(FileOutputStream out=new FileOutputStream(new File(c.getFilesDir(),"jwd-scan-screen.png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}
            runOnMainSync(()->c.startForegroundService(new Intent(c,JwdService.class).setAction("disconnect")));Thread.sleep(600);require(!JwdService.active,"Foreground service must stop");pass("disconnect_releases_service");
            success=true;
        }catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        finally{if(activity!=null){JwdActivity a=activity;runOnMainSync(a::finish);}try{report.put("checks",checks).put("all_passed",success).put("android_api",Build.VERSION.SDK_INT).put("scope","Emulator runtime permissions, BLE scanning lifecycle, no physical JWD device.");Files.write(new File(c.getFilesDir(),"jwd-ui-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}Bundle b=new Bundle();b.putString("stream",report.toString());finish(success?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);}
    }
}
