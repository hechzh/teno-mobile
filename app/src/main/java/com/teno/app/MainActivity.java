package com.teno.app;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import java.util.ArrayList;
import java.util.Locale;
import java.util.function.Consumer;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

/** Stable entry point for launchers, recording notifications and upgrades. */
public class MainActivity extends FlutterActivity {
    NativeRuntime runtime;
    private Runnable permissionGranted;
    private Consumer<Throwable> permissionDenied;
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        runtime = new NativeRuntime(this, engine.getDartExecutor().getBinaryMessenger());
        runtime.acceptIntent(getIntent());
    }
    @Override public void onCreate(Bundle state) { super.onCreate(state); new Store(this).recoverRecordings(); }
    @Override protected void onResume() { super.onResume(); UploadQueue.resume(this); if(runtime!=null)runtime.resume(); }
    @Override protected void onPause() { if(runtime!=null)runtime.suspendUi(); super.onPause(); }
    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent);setIntent(intent);if(runtime!=null)runtime.acceptIntent(intent); }
    void permissions(String[] names,Runnable granted,Consumer<Throwable> denied) {
        runOnUiThread(()->{
            if(permissionGranted!=null){denied.accept(new IllegalStateException("Finish the current permission request first."));return;}
            ArrayList<String> missing=new ArrayList<>();
            for(String name:names)if(checkSelfPermission(name)!=PackageManager.PERMISSION_GRANTED)missing.add(name);
            if(missing.isEmpty()){granted.run();return;}
            permissionGranted=granted;permissionDenied=denied;requestPermissions(missing.toArray(new String[0]),510);
        });
    }
    @Override public void onRequestPermissionsResult(int request,String[] names,int[] results){
        super.onRequestPermissionsResult(request,names,results);
        if(request!=510||permissionGranted==null)return;
        Runnable granted=permissionGranted;Consumer<Throwable> denied=permissionDenied;
        permissionGranted=null;permissionDenied=null;boolean allowed=results.length>0;
        for(int result:results)allowed&=result==PackageManager.PERMISSION_GRANTED;
        if(allowed)granted.run();else denied.accept(new SecurityException("Permission was not granted. Enable it in Android Settings to use this feature."));
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);if(runtime!=null)runtime.media.activityResult(request,result,data);
    }
    @Override protected void onDestroy(){if(runtime!=null)runtime.close();super.onDestroy();}
    static String clock(long ms){long seconds=Math.max(0,ms)/1000;return String.format(Locale.ROOT,"%02d:%02d",seconds/60,seconds%60);}
}
