package com.teno.app;

import android.Manifest;
import android.app.*;
import android.bluetooth.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.location.LocationManager;
import android.media.MediaPlayer;
import android.os.*;
import android.text.InputType;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Recorder control, automatic verified local sync and optional cloud processing. */
public class JwdActivity extends EnglishActivity {
    private boolean startRequested,entryPrepared,reconnectRequested,wasRecording,followSync;private long startDeadline;
    private Store store;private LinearLayout content;private ScrollView scroll;private TextView timer,liveWords,liveDraft,liveStatus;private String view="device";
    private final Handler handler=new Handler(Looper.getMainLooper());private MediaPlayer player;
    private String pendingKeyAddress="";private String last="",lastDrafts="",lastTransfer="",exportText="";private boolean foreground,showOtherDevices,compatScanRequested;
    private static final int BG=0xfff6f7f3,INK=0xff20251f,MUTED=0xff72786e,PURPLE=0xff20251f;
    @Override public void onCreate(Bundle state){super.onCreate(state);store=new Store(this);startRequested=state==null&&getIntent().getBooleanExtra("start_recording",false);getIntent().removeExtra("start_recording");render();}
    @Override public void onResume(){super.onResume();foreground=true;handler.post(tick);if(!entryPrepared){entryPrepared=true;if(startRequested)handler.post(()->RecordingOptions.ensure(this,this::prepareEntry));}}
    @Override public void onPause(){super.onPause();foreground=false;handler.removeCallbacks(tick);releasePlayer();}
    @Override public void onStop(){super.onStop();if(startRequested){startRequested=false;if(JwdService.active)send("resume_sync");}}
    @Override public void onDestroy(){handler.removeCallbacksAndMessages(null);releasePlayer();super.onDestroy();}
    private final Runnable tick=new Runnable(){public void run(){
        if(!foreground)return;
        advanceEntry();
        String drafts=store.scope().isEmpty()?"[]":store.drafts().toString(),transfer=TransferService.active+":"+TransferService.message;
        if(!last.equals(JwdService.snapshot)||!lastDrafts.equals(drafts)||!lastTransfer.equals(transfer))render();
        try{JSONObject s=new JSONObject(JwdService.snapshot);if(timer!=null&&s.optInt("record_state",-1)==1){long seconds=Math.max(0,(SystemClock.elapsedRealtime()-s.optLong("record_start"))/1000);timer.setText(String.format(Locale.ROOT,"%02d:%02d",seconds/60,seconds%60));}}catch(Exception ignored){}
        updateLive();handler.postDelayed(this,800);
    }};
    private int dp(int x){return (int)(x*getResources().getDisplayMetrics().density+.5f);}
    private LinearLayout column(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.VERTICAL);return v;}
    private TextView text(String value,int size,int color){TextView t=new TextView(this);t.setText(value);t.setTextSize(size);t.setTextColor(color);t.setPadding(0,dp(4),0,dp(6));t.setLineSpacing(dp(3),1);return t;}
    private void title(LinearLayout parent,String title){TextView t=text(title,20,INK);t.setTypeface(null,Typeface.BOLD);parent.addView(t);}
    private LinearLayout card(String title){LinearLayout c=column();c.setPadding(dp(16),dp(14),dp(16),dp(14));GradientDrawable bg=new GradientDrawable();bg.setColor(Color.WHITE);bg.setCornerRadius(dp(16));c.setBackground(bg);LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,-2);p.setMargins(0,dp(6),0,dp(8));content.addView(c,p);if(!title.isEmpty())title(c,title);return c;}
    private void button(LinearLayout parent,String label,boolean enabled,Runnable action){Button b=new Button(this);b.setText(label);b.setTextSize(14);b.setAllCaps(false);b.setEnabled(enabled);b.setMinHeight(dp(48));b.setMinimumHeight(dp(48));b.setPadding(dp(16),dp(10),dp(16),dp(10));b.setStateListAnimator(null);boolean primary=label.startsWith("Start")||label.startsWith("Scan for")||label.equals("Stop and save")||label.equals("Upload recording")||label.startsWith("Connect:");b.setTextColor(!enabled?MUTED:primary?Color.WHITE:INK);GradientDrawable bg=new GradientDrawable();bg.setColor(!enabled?0xffeceee7:primary?INK:Color.WHITE);bg.setCornerRadius(dp(28));bg.setStroke(dp(1),0xffdfe2d9);b.setBackground(bg);b.setContentDescription(label);b.setOnClickListener(v->action.run());LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.setMargins(0,dp(6),0,dp(4));parent.addView(b,lp);}
    @Override public void onBackPressed(){if(!view.equals("device")){view="device";render();}else super.onBackPressed();}
    private void navigate(String page){view=page;render();scroll.scrollTo(0,0);}
    private void updateLive(){JwdLiveSession session=JwdService.live;if(liveWords==null||session==null)return;StringBuilder words=new StringBuilder();JSONArray segments=session.transcriber.segments();for(int n=0;n<segments.length();n++){JSONObject item=segments.optJSONObject(n);if(item!=null)words.append(MainActivity.clock(item.optLong("start_ms"))).append("  ").append(item.optString("text")).append("\n\n");}liveWords.setText(words.length()==0?"Your transcript will appear here.":words.toString().trim());liveDraft.setText(session.transcriber.partial);liveStatus.setText(!session.problem.isEmpty()?session.problem:session.samples==0?"Waiting for recorder audio":session.transcriber.status);}
    private void prepareEntry(){
        startDeadline=SystemClock.elapsedRealtime()+45000;
        try{JSONObject state=new JSONObject(JwdService.snapshot);
            if(state.optInt("record_state",-1)==1){startRequested=false;wasRecording=true;followSync=true;navigate("live");return;}
            if(state.optBoolean("connected")||JwdService.active&&!state.optString("pending").isEmpty()){send("prepare_recording");advanceEntry();return;}
        }catch(Exception ignored){}
        if(!store.recorderAddress().isEmpty()){reconnectRequested=true;permissionsAndScan(false);}else permissionsAndScan();
    }
    private void advanceEntry(){
        try{JSONObject state=new JSONObject(JwdService.snapshot);
            if(startRequested&&startDeadline>0){
                if(SystemClock.elapsedRealtime()>startDeadline){startRequested=false;if(JwdService.active)send("resume_sync");}
                else if(state.optInt("record_state",-1)==1){startRequested=false;wasRecording=true;followSync=true;view="live";last="";}
                else if(state.optBoolean("authorized")&&state.optInt("record_state",-1)==0&&!state.optBoolean("busy")){startRequested=false;startRecording();}
            }
            if(view.equals("live")&&state.optInt("record_state",-1)==1)wasRecording=true;
            if(view.equals("live")&&wasRecording&&state.optInt("record_state",-1)==0){view="sync";last="";wasRecording=false;}
            if(view.equals("sync")&&followSync&&!state.optString("last_draft").isEmpty()){
                followSync=false;startActivity(new Intent(this,MainActivity.class).putExtra("draft_id",state.optString("last_draft")));finish();
            }
        }catch(Exception ignored){}
    }
    private void startRecording(){
        RecordingOptions.ensure(this,()->{startRequested=false;followSync=true;wasRecording=false;navigate("live");send(new Intent(this,JwdService.class).setAction("start").putExtra("live",!store.token("access_token").isEmpty()&&store.liveDefault()));});
    }

    private void error(String message){new AlertDialog.Builder(this).setTitle("Recorder").setMessage(message).setPositiveButton("OK",null).show();}
    private void render(){
        int y=scroll==null?0:scroll.getScrollY();last=JwdService.snapshot;lastDrafts=store.scope().isEmpty()?"[]":store.drafts().toString();lastTransfer=TransferService.active+":"+TransferService.message;
        JSONObject s;try{s=new JSONObject(last);}catch(Exception e){s=new JSONObject();}final JSONObject state=s;
        LinearLayout root=column();root.setBackgroundColor(BG);root.setPadding(dp(22),dp(12),dp(22),0);
        LinearLayout header=new LinearLayout(this);header.setGravity(Gravity.CENTER_VERTICAL);ImageButton back=new ImageButton(this);back.setImageResource(R.drawable.ic_arrow_left);back.setBackgroundColor(Color.TRANSPARENT);back.setContentDescription("Back");back.setOnClickListener(v->onBackPressed());header.addView(back,new LinearLayout.LayoutParams(dp(44),dp(44)));TextView heading=text(view.equals("files")?"Device recordings":view.equals("live")?"Recorder audio":view.equals("settings")?"Recorder settings":view.equals("sync")?"Syncing recording":"Recorder",18,INK);header.addView(heading,new LinearLayout.LayoutParams(0,-2,1));root.addView(header);
        scroll=new ScrollView(this);content=column();content.setPadding(0,dp(12),0,dp(24));scroll.addView(content);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));setContentView(root);timer=null;liveWords=null;liveDraft=null;liveStatus=null;
        boolean connected=s.optBoolean("connected"),authorized=s.optBoolean("authorized"),busy=s.optBoolean("busy"),scanning=s.optBoolean("scanning");int recording=s.optInt("record_state",-1);
        if(view.equals("settings")){
            LinearLayout info=card(s.optString("name","Recorder"));info.addView(text("Firmware: "+(s.optString("firmware").isEmpty()?"Not received":s.optString("firmware"))+"\n"+s.optString("capacity"),14,MUTED));
            if(!s.optString("address").isEmpty())button(info,"Device key and backup",!busy,()->keyOptions(state.optString("address"),state.optString("name")));
            button(info,"Recording preferences",true,()->RecordingOptions.show(this,null));
            button(info,"Buttons and reset",true,this::buttonsHelp);button(info,"Connection help",true,this::identificationHelp);button(info,"Export diagnostics",true,this::exportDiagnostics);
            info.addView(text("Wi-Fi transfer and firmware updates are not available in this version.",13,MUTED));
            if(JwdService.active)button(info,"Disconnect recorder",!s.optBoolean("converting"),()->new AlertDialog.Builder(this).setTitle("Disconnect recorder?").setMessage(recording==1?"Disconnecting does not stop the recording. Use Stop and save first, or stop it on the recorder.":"Files and the saved device key will be kept.").setPositiveButton("Disconnect",(d,w)->{send("disconnect");navigate("device");}).setNegativeButton("Cancel",null).show());
        }else if(view.equals("sync")){
            LinearLayout progress=card("Syncing recording");
            progress.addView(text(s.optString("message","Waiting for the saved file"),16,INK));
            progress.addView(text("The original is saved on your recorder. A verified copy will be kept on this phone automatically.",14,MUTED));
            long total=s.optLong("expected"),received=s.optLong("received");if(total>0)progress.addView(text(received*100/total+"% received",14,INK));
            if(!s.optString("sync_error").isEmpty())progress.addView(text(s.optString("sync_error"),14,0xffad4941));
            if(authorized&&!busy)button(progress,"Retry sync",true,()->send("sync"));
            if(!authorized&&!busy)button(progress,"Reconnect recorder",true,()->{reconnectRequested=true;permissionsAndScan(false);});
            if(busy)button(progress,"Pause sync",!s.optBoolean("converting"),()->send("cancel"));
            button(content,"Back to library",true,this::finish);
            button(content,"Device recordings",!busy,()->navigate("files"));
        }else if(view.equals("live")){
            content.addView(text(s.optString("name","Recorder"),13,MUTED));timer=text("00:00",40,INK);content.addView(timer);content.addView(text(recording==1?"Recording on device":busy?"Waiting for device confirmation":recording==0?"Saved on recorder":"Device status unknown",14,MUTED));
            LinearLayout transcript=card("Live transcript");liveStatus=text("Live transcription is off",12,MUTED);transcript.addView(liveStatus);liveWords=text(JwdService.live==null?(recording==1?"Audio is being saved on your recorder.":"Live transcription is off."):"Your transcript will appear here.",17,INK);liveWords.setTextIsSelectable(true);transcript.addView(liveWords);liveDraft=text("",17,MUTED);transcript.addView(liveDraft);updateLive();
            if(recording==1)button(content,"Stop and save",authorized&&!busy,()->send("stop"));else if(recording==0)button(content,"View sync status",true,()->navigate("sync"));
            if(JwdService.live!=null&&!JwdService.live.finished)button(content,"Retry live transcription",!busy,()->JwdService.live.transcriber.retry());
            content.addView(text("A copy stays on the recorder. After stopping, audio syncs to this phone automatically. Cloud processing follows your recording preferences.",13,MUTED));
            if(!authorized)content.addView(text("Connection ended. The device may still be recording. Check its status before reconnecting.",14,0xffad4941));
        }else if(view.equals("files")){
            content.addView(text(s.optString("message"),14,INK));
            if(s.optBoolean("receiving")||s.optBoolean("converting")){LinearLayout progress=card("Importing recording");long total=s.optLong("expected"),received=s.optLong("received");progress.addView(text(s.optBoolean("converting")?"Checking and preparing audio":total>0?received*100/total+"% · "+received+" / "+total+" bytes":"Waiting for recorder",15,INK));ProgressBar bar=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);bar.setIndeterminate(total==0);bar.setProgress(total==0?0:(int)(received*100/total));progress.addView(bar);button(progress,"Cancel import",!s.optBoolean("converting"),()->send("cancel"));}
            button(content,"Refresh device files",authorized&&!busy&&recording==0,()->send("refresh"));
            JSONArray dirs=s.optJSONArray("dirs"),files=s.optJSONArray("files");if(dirs==null||dirs.length()==0)content.addView(text(recording==1?"Stop recording before importing files.":"No device files loaded. Connect your recorder and refresh.",14,MUTED));
            if(dirs!=null)for(int i=0;i<dirs.length();i++){String dir=dirs.optString(i);button(content,dir,!busy&&recording==0,()->send(new Intent(this,JwdService.class).setAction("files").putExtra("dir",dir)));}
            if(files!=null)for(int i=0;i<files.length();i++){JSONObject f=files.optJSONObject(i);if(f==null)continue;String dir=s.optString("directory");LinearLayout file=card(f.optString("name"));file.addView(text(MainActivity.clock(f.optLong("seconds")*1000),13,MUTED));button(file,"Import to phone",authorized&&!busy&&recording==0,()->{if(store.scope().isEmpty()){error("Sign in to import recordings.");return;}send(new Intent(this,JwdService.class).setAction("download").putExtra("dir",dir).putExtra("file",f.optString("name")));});}
            LinearLayout local=card("On this phone");int count=0;JSONArray drafts=store.drafts();for(int i=0;i<drafts.length();i++){JSONObject d=drafts.optJSONObject(i);if(d==null||!d.optString("source").equals("jwd_ble"))continue;count++;title(local,d.optString("title"));boolean uploaded=!d.optString("recording_id").isEmpty();local.addView(text((uploaded?"Uploaded · Local copy kept":UploadQueue.label(store,d))+" · "+MainActivity.clock(d.optLong("duration_ms"))+"\n"+(d.optString("jwd_verification").equals("crc32_verified")?"Checksum verified":"Length verified · Device checksum unavailable"),13,MUTED));if(!d.optString("error").isEmpty())local.addView(text(d.optString("error"),13,0xffad4941));button(local,"Play / stop audio",true,()->play(d));button(local,uploaded?"View in library":"Upload recording",!UploadQueue.requested(store,d),()->{if(uploaded){startActivity(new Intent(this,MainActivity.class).putExtra("recording_id",d.optString("recording_id")));finish();}else upload(d);});}
            if(count==0)local.addView(text("Imported files appear here. The originals stay on your recorder.",14,MUTED));if(TransferService.active)local.addView(text(TransferService.message,14,INK));
        }else{
            content.addView(text(connected?"Your recorder":"Connect your recorder",28,INK));content.addView(text(s.optString("message","Scan for a recorder to get started."),14,MUTED));
            if(connected){LinearLayout info=card(s.optString("name","Recorder"));info.addView(text((authorized?"Connected":"Authorizing")+" · "+s.optString("battery","Battery unavailable"),14,MUTED));info.addView(text(recording==1?"Recording in progress":recording==0?"Ready to record":"Checking recording status",15,INK));button(info,recording==1?"Open recording":"Start recording",authorized&&!busy,()->{if(recording==1){wasRecording=true;followSync=true;navigate("live");}else startRecording();});button(info,"Device recordings",authorized&&!busy,()->navigate("files"));}
            else{
                if(!store.recorderAddress().isEmpty())button(content,"Reconnect "+store.recorderName(),!scanning&&!busy,()->{reconnectRequested=true;permissionsAndScan(false);});
                button(content,scanning?"Scanning…":"Scan for devices",!scanning&&!busy,this::permissionsAndScan);
                JSONArray devices=s.optJSONArray("devices");ArrayList<JSONObject> candidates=new ArrayList<>(),others=new ArrayList<>();if(devices!=null)for(int i=0;i<devices.length();i++){JSONObject d=devices.optJSONObject(i);if(d!=null){if(deviceRank(d)<3)candidates.add(d);else others.add(d);}}
                candidates.sort((a,b)->{int rank=Integer.compare(deviceRank(a),deviceRank(b));return rank!=0?rank:Integer.compare(b.optInt("rssi",-200),a.optInt("rssi",-200));});
                for(JSONObject d:candidates)deviceRow(card(""),d,busy);if(candidates.isEmpty())content.addView(text("Keep the recorder nearby and available for connection. Close other recorder apps before scanning.",14,MUTED));
                if(!others.isEmpty()){button(content,(showOtherDevices?"Hide ":"Show ")+"other devices ("+others.size()+")",!busy,()->{showOtherDevices=!showOtherDevices;render();});if(showOtherDevices)for(JSONObject d:others)deviceRow(card(""),d,busy);}
                button(content,"Try compatibility scan",!scanning&&!busy,()->permissionsAndScan(true));
            }
            if(s.optBoolean("system_pairing_requested"))content.addView(text("Android requested pairing. Cancel that prompt and check Connection help. It is separate from the device key.",14,0xffad4941));
            if(s.optBoolean("syncing")||s.optBoolean("receiving"))button(content,"View sync status",true,()->navigate("sync"));
            button(content,"Recorder settings and help",!busy,()->navigate("settings"));
            if(!s.optString("address").isEmpty()&&!authorized)button(content,"Enter original device key",!busy,()->editKey(state.optString("address"),state.optString("name")));
            if(!store.scope().isEmpty())button(content,"Imported recordings",true,()->navigate("files"));else content.addView(text("Sign in to import audio or use live transcription.",13,MUTED));
        }
        scroll.post(()->scroll.scrollTo(0,y));
    }
    private void buttonsHelp(){new AlertDialog.Builder(this).setTitle("Buttons and reset").setMessage("Reset deletes device recordings and removes its binding. Back up the files and device key first.\n\nTo reset: wake the device, press the recording button three times quickly, wait for the red light to flash, then hold the button for about five seconds. The protocol describes a steady green light at completion; the SDK FAQ describes blue for some firmware. Confirm the indication for your model.\n\nThe supplied documents support starting and stopping from the device button, but do not specify a universal press duration for normal recording or power.\n\nStopping a recording saves its file. Teno never resets or formats your recorder automatically.").setPositiveButton("Close",null).show();}
    static int deviceRank(JSONObject d){
        if(d.optString("gatt_status").equals("unsupported"))return 3;
        if(d.optString("gatt_status").equals("verified"))return 0;
        if(d.optBoolean("jwd"))return 1;
        if(d.optBoolean("name_match")||JwdProtocol.candidateName(d.optString("name")))return 2;
        return 3;
    }
    static String deviceEvidence(JSONObject d){
        switch(deviceRank(d)){
            case 0:return "Recording service verified";
            case 1:return "Service advertised · Verification needed";
            case 2:return "Possible recorder · Check service";
            default:return d.optString("gatt_status").equals("unsupported")?"Service not supported":"Unknown device · Check its identity";
        }
    }
    private void deviceRow(LinearLayout parent,JSONObject d,boolean busy){
        String name=d.optString("name");TextView nameView=text(name,16,INK);nameView.setTypeface(null,Typeface.BOLD);parent.addView(nameView);
        parent.addView(text(deviceEvidence(d)+"\n"+d.optString("address")+" · "+d.optInt("rssi")+" dBm",12,deviceRank(d)==0?0xff2b8465:MUTED));
        if(deviceRank(d)==0)button(parent,"Connect: "+name,!busy,()->connect(d));
        else button(parent,"Check service: "+name,!busy,()->send(new Intent(this,JwdService.class).setAction("probe").putExtra("address",d.optString("address")).putExtra("name",name)));
    }
    private boolean hasSavedKey(String address){try{return !store.deviceKey(address).isEmpty();}catch(Exception e){return true;}}
    private void identificationHelp(){
        new AlertDialog.Builder(this).setTitle("Verify the recorder").setMessage("Scan within Teno. Device names vary by model; verify the recording service before connecting. Service ID: "+JwdProtocol.SERVICE+".\n\nEnter the 16-character device key on this phone. It is separate from Android Bluetooth pairing. If Android asks you to enter a number on another device, cancel and verify the recorder.\n\nTo identify the recorder, stop recording and compare scan results with the device off and on. See Buttons and reset before resetting it.")
            .setPositiveButton("OK",null).show();
    }
    private void permissionsAndScan(){reconnectRequested=false;permissionsAndScan(false);}
    private void permissionsAndScan(boolean compatibility){
        compatScanRequested=compatibility;
        ArrayList<String> missing=new ArrayList<>();
        String[] required=Build.VERSION.SDK_INT>=31?new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT}:new String[]{Manifest.permission.ACCESS_FINE_LOCATION};
        for(String p:required)if(checkSelfPermission(p)!=PackageManager.PERMISSION_GRANTED)missing.add(p);
        if(!missing.isEmpty()){requestPermissions(missing.toArray(new String[0]),31);return;}
        BluetoothAdapter adapter=((BluetoothManager)getSystemService(BLUETOOTH_SERVICE)).getAdapter();if(adapter==null){error("Bluetooth is unavailable on this device.");return;}
        if(!adapter.isEnabled()){startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),32);return;}
        if(Build.VERSION.SDK_INT<31&&!((LocationManager)getSystemService(LOCATION_SERVICE)).isProviderEnabled(LocationManager.GPS_PROVIDER)){error("Android 8–11 requires Location to scan for Bluetooth devices. Teno does not record your location.");return;}
        if(reconnectRequested&&!store.recorderAddress().isEmpty()){reconnectRequested=false;connectSaved(store.recorderAddress(),store.recorderName());return;}
        send(compatibility?"scan_compat":"scan");
    }
    @Override public void onRequestPermissionsResult(int request,String[] p,int[] grants){super.onRequestPermissionsResult(request,p,grants);if(request==31){boolean ok=grants.length>0;for(int g:grants)ok&=g==PackageManager.PERMISSION_GRANTED;if(ok)permissionsAndScan(compatScanRequested);else error("Allow Nearby devices in Android Settings > Apps > Teno > Permissions, then scan again.");}}
    private void connect(JSONObject device){
        String address=device.optString("address"),name=device.optString("name");
        try{
            if(!store.deviceKey(address).isEmpty()){connectSaved(address,name);return;}
            new AlertDialog.Builder(this).setTitle("Connect "+name).setMessage("The recording service is verified. A new binding creates a 16-character key on this phone. If the recorder is already bound, enter its original key.")
                .setPositiveButton("Set up new binding",(d,w)->{try{store.deviceKey(address,JwdProtocol.newKey());connectSaved(address,name);}catch(Exception e){error(e.getMessage());}})
                .setNeutralButton("Enter original key",(d,w)->editKey(address,name)).setNegativeButton("Cancel",null).show();
        }catch(Exception e){error("The saved key could not be read. Enter the original key from Device key.");}
    }
    private void connectSaved(String address,String name){send(new Intent(this,JwdService.class).setAction("connect").putExtra("address",address).putExtra("name",name).putExtra("defer_sync",startRequested));}
    private void keyOptions(String address,String name){
        new AlertDialog.Builder(this).setTitle("Device key").setMessage("Uninstalling Teno or clearing its data removes the saved key. Back it up first. A recorder bound by another app requires its original key.")
            .setPositiveButton("View saved key",(d,w)->{KeyguardManager keyguard=(KeyguardManager)getSystemService(KEYGUARD_SERVICE);Intent unlock=keyguard.createConfirmDeviceCredentialIntent("View device key","Confirm your screen lock to view the saved key.");if(unlock==null){error("Set a screen lock in Android Settings before viewing the device key.");return;}pendingKeyAddress=address;startActivityForResult(unlock,34);})
            .setNeutralButton("Enter key and reconnect",(d,w)->editKey(address,name)).setNegativeButton("Cancel",null).show();
    }
    private void editKey(String address,String name){
        EditText input=new EditText(this);input.setSingleLine(true);input.setHint("16 letters or numbers");input.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD);
        AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Original device key").setView(input).setPositiveButton("Save and connect",null).setNegativeButton("Cancel",null).create();
        dialog.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);dialog.setOnShowListener(d->dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->{try{store.deviceKey(address,input.getText().toString().trim());input.setText("");dialog.dismiss();connectSaved(address,name);}catch(Exception e){input.setError(e.getMessage());}}));dialog.show();
    }
    private void send(String action){send(new Intent(this,JwdService.class).setAction(action));}
    private void send(Intent intent){try{startForegroundService(intent);}catch(Exception e){error("Recorder service could not start. Check Bluetooth permissions: "+e.getMessage());}}
    private void play(JSONObject draft){
        if(player!=null){releasePlayer();return;}
        try{player=new MediaPlayer();player.setDataSource(draft.getString("path"));player.setOnPreparedListener(MediaPlayer::start);player.setOnCompletionListener(p->releasePlayer());player.setOnErrorListener((p,a,b)->{releasePlayer();error("This audio could not be played. Export diagnostics for review.");return true;});player.prepareAsync();}catch(Exception e){releasePlayer();error(e.getMessage());}
    }
    private void releasePlayer(){if(player!=null){player.release();player=null;}}
    private void upload(JSONObject draft){
        if(store.token("access_token").isEmpty()){error("Sign in to the same Teno account first");return;}
        try{UploadQueue.enqueue(store,draft.getString("id"),false);UploadQueue.resume(this);}catch(Exception e){error(e.getMessage());}
    }
    private void exportDiagnostics(){
        try{JSONObject diagnostics=new JSONObject(JwdService.snapshot);diagnostics.put("app_version","0.4.4").put("phone",Build.MANUFACTURER+" "+Build.MODEL).put("android",Build.VERSION.RELEASE).put("api",Build.VERSION.SDK_INT).put("abis",new JSONArray(Arrays.asList(Build.SUPPORTED_ABIS))).put("hardware_validation","pending_user_device_test");
            if(JwdService.live!=null)diagnostics.put("live_status",JwdService.live.transcriber.status).put("live_samples",JwdService.live.samples).put("live_error",JwdService.live.problem);diagnostics.remove("address");diagnostics.remove("devices");exportText=diagnostics.toString(2);
            startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("application/json").addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE,"Teno-JWD-diagnostics.json"),33);
        }catch(Exception e){error(e.getMessage());}
    }
    @Override public void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request==34){if(result==RESULT_OK&&!pendingKeyAddress.isEmpty())try{String key=store.deviceKey(pendingKeyAddress);AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Keep this key private").setMessage(key.isEmpty()?"No saved key":key).setPositiveButton("Close",null).create();dialog.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);dialog.show();}catch(Exception e){error("The key could not be decrypted. Enter the original key.");}pendingKeyAddress="";return;}if(request==32&&result==RESULT_OK){permissionsAndScan(compatScanRequested);return;}
        if(request==33&&result==RESULT_OK&&data!=null&&data.getData()!=null){try(OutputStream out=getContentResolver().openOutputStream(data.getData())){if(out==null)throw new IOException("The file could not be written");out.write(exportText.getBytes(StandardCharsets.UTF_8));Toast.makeText(this,"Diagnostics saved. Device keys and account tokens are excluded.",Toast.LENGTH_LONG).show();}catch(Exception e){error(e.getMessage());}}
    }
}
