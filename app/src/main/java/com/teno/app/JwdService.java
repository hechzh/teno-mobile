package com.teno.app;

import android.annotation.SuppressLint;
import android.app.*;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.*;
import android.os.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.*;

/** Hardware transport stays alive when the Activity is backgrounded. No recording is auto-deleted. */
@SuppressLint("MissingPermission")
public final class JwdService extends Service implements JwdBle.Listener {
    public static volatile boolean active=false;
    public static volatile String snapshot="{}";
    static volatile JwdLiveSession live;
    private boolean requestLive;
    private HandlerThread thread;private Handler handler;private JwdTransport ble;private Store store;
    private final ExecutorService decoder=Executors.newSingleThreadExecutor();
    private BluetoothLeScanner scanner;private BluetoothAdapter adapter;private PowerManager.WakeLock wake;
    private boolean scanning,compatibilityScanning,connected,authorized,converting,destroyed;
    private boolean autoDiscovery,autoProbing;
    private final ArrayDeque<String> autoQueue=new ArrayDeque<>();
    private final HashSet<String> autoTried=new HashSet<>();
    private String preferredRecorder="";
    private boolean pairingRequested,gattVerified;private int pairingVariant=-1;
    private String connectionStage="",pairingStage="";
    private String address="",deviceName="",message="Not connected",firmware="",capacity="",battery="Not received",directory="",pending="",recordName="",lastDraft="";
    private int recordState=-1;private long recordStart,recordPausedAt,recordPausedTotal,operation,lastData,lastPublish;
    private final LinkedHashMap<String,JSONObject> found=new LinkedHashMap<>();
    private final ArrayList<String> dirs=new ArrayList<>(),logs=new ArrayList<>();
    private final ArrayList<JSONObject> files=new ArrayList<>();
    private JwdProtocol.Receiver receiver;private File raw;
    private String downloadName="",downloadDir="",downloadScope="";private long downloadSeconds;private boolean endSeen;
    private boolean syncing,deferSync;private String syncScope="",syncTarget="",syncError="";private int syncDirectory,syncRetry;
    private final ArrayList<JSONObject> syncFiles=new ArrayList<>();
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public void onCreate(){
        super.onCreate();store=new Store(this);thread=new HandlerThread("Teno-JWD");thread.start();handler=new Handler(thread.getLooper());ble=new JwdBle(this,handler,this);
        adapter=((BluetoothManager)getSystemService(BLUETOOTH_SERVICE)).getAdapter();
        IntentFilter pairingFilter=new IntentFilter(BluetoothDevice.ACTION_PAIRING_REQUEST);
        pairingFilter.addAction(BluetoothDevice.ACTION_FOUND);pairingFilter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        if(Build.VERSION.SDK_INT>=33)registerReceiver(pairingReceiver,pairingFilter,Context.RECEIVER_EXPORTED);else registerReceiver(pairingReceiver,pairingFilter);
        RecorderService.channel(this,"jwd","Recorder connection");
        wake=((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"Teno:JwdTransfer");
    }
    private final BroadcastReceiver pairingReceiver=new BroadcastReceiver(){@Override public void onReceive(Context c,Intent i){
        if(BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(i.getAction())){handler.post(()->{if(scanning&&compatibilityScanning)scanStop.run();});return;}
        BluetoothDevice device=i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);if(device==null)return;
        if(BluetoothDevice.ACTION_FOUND.equals(i.getAction())){
            String name=i.getStringExtra(BluetoothDevice.EXTRA_NAME);int rssi=i.getShortExtra(BluetoothDevice.EXTRA_RSSI,(short)-200);
            handler.post(()->{if(scanning&&compatibilityScanning)recordFound(device,name,rssi,false,"sdk_discovery");});return;
        }
        String mac=device.getAddress();int variant=i.getIntExtra(BluetoothDevice.EXTRA_PAIRING_VARIANT,-1);
        handler.post(()->{
            if(destroyed||!mac.equals(address)||(!connected&&!pending.equals("connect")&&!pending.equals("probe")&&!pending.equals("auth")))return;
            pairingRequested=true;pairingVariant=variant;pairingStage=connectionStage;
            message="Android requested Bluetooth pairing. Cancel the prompt and export diagnostics. This is separate from the device key.";
            log("System pairing request, type "+variant+", stage "+connectionStage+", service verified="+gattVerified);publish();
            // Do not read EXTRA_PAIRING_KEY, guess a PIN, call setPin, or confirm pairing for the user.
        });
    }};
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        active=true;startForeground(13,notification("Recorder service"));
        if(intent==null){stopSelf();return START_NOT_STICKY;}
        handler.post(()->{try{handle(intent);}catch(Exception e){problem(e.getMessage());}});return START_NOT_STICKY;
    }
    private Notification notification(String text){
        PendingIntent open=PendingIntent.getActivity(this,13,new Intent(this,MainActivity.class).putExtra("open_device",true),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        PendingIntent stop=PendingIntent.getService(this,14,new Intent(this,JwdService.class).setAction("disconnect"),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this,"jwd").setSmallIcon(R.drawable.ic_app).setContentTitle(UiLocale.text(this,"Teno · Recorder")).setContentText(UiLocale.text(this,text)).setContentIntent(open).setOngoing(true).addAction(new Notification.Action.Builder(null,UiLocale.text(this,"Disconnect"),stop).build()).build();
    }
    private void handle(Intent i)throws Exception{
        String action=i.getAction();if(action==null)return;
        if(action.equals("prepare_recording")){deferSync=true;syncing=false;syncFiles.clear();publish();return;}
        if(action.equals("resume_sync")){deferSync=false;if(authorized&&recordState==0&&pending.isEmpty()&&receiver==null&&!converting)startSync();return;}
        if(action.equals("disconnect")){cancelAutomaticConnection();if(converting)throw new IOException("Wait for the decoded file to finish saving before disconnecting");stopLive(false);stopScan();abortTransfer();resetSync();ble.close();connected=false;authorized=false;recordState=-1;pending="";operation++;message="Disconnected. Check the recorder: it may still be recording.";publish();stopSelf();return;}
        if(action.equals("scan")||action.equals("scan_compat")){scan(action.equals("scan_compat"));return;}
        if(action.equals("probe")){
            if(!i.getBooleanExtra("automatic",false))cancelAutomaticConnection();
            if(connected||converting||receiver!=null||!pending.isEmpty())throw new IOException("Disconnect the current device or wait for verification to finish");
            String candidate=i.getStringExtra("address");if(!BluetoothAdapter.checkBluetoothAddress(candidate))throw new IOException("Invalid Bluetooth address");
            if(adapter==null||!adapter.isEnabled())throw new IOException("Turn on Bluetooth");
            stopScan();address=candidate;deviceName=i.getStringExtra("name");if(deviceName==null)deviceName="Unnamed device";
            pairingRequested=false;pairingVariant=-1;pairingStage="";gattVerified=false;connectionStage="connecting";
            authorized=false;recordState=-1;firmware="";battery="Not received";capacity="";dirs.clear();files.clear();directory="";
            begin("probe","Verifying recorder protocol",27000);log("Checking device services");ble.probe(adapter.getRemoteDevice(address));publish();return;
        }
        if(action.equals("connect")){
            if(!i.getBooleanExtra("automatic",false))cancelAutomaticConnection();
            if(converting||receiver!=null)throw new IOException("Finish or cancel the current transfer first");
            lastDraft="";syncTarget="";
            stopScan();ble.close();abortTransfer();resetSync();deferSync=i.getBooleanExtra("defer_sync",false);operation++;pending="";authorized=false;connected=false;recordState=-1;recordName="";firmware="";capacity="";battery="Not received";dirs.clear();files.clear();directory="";
            address=i.getStringExtra("address");deviceName=i.getStringExtra("name");if(deviceName==null)deviceName="JWD recorder";
            pairingRequested=false;pairingVariant=-1;pairingStage="";gattVerified=false;connectionStage="connecting";
            if(!BluetoothAdapter.checkBluetoothAddress(address))throw new IOException("Invalid Bluetooth address");
            if(store.deviceKey(address).isEmpty())throw new IOException("Save a device key before connecting");
            if(adapter==null||!adapter.isEnabled())throw new IOException("Turn on Bluetooth");
            begin("connect","Connecting automatically",27000);log("Connecting recorder");ble.connect(adapter.getRemoteDevice(address));handler.postDelayed(()->{if(deferSync){deferSync=false;if(authorized&&recordState==0&&pending.isEmpty())try{startSync();}catch(Exception e){syncFailed(e.getMessage());}}},45000);publish();return;
        }
        if(!authorized)throw new IOException("Connect and authorize the recorder first");
        if(action.equals("cancel")){
            if(converting)throw new IOException("Decoding audio…");
            // Close the connection to fence late packets before another file transfer can start.
            abortTransfer();resetSync();ble.close();connected=false;authorized=false;recordState=-1;pending="";operation++;message="Sync paused. Originals stay on the recorder. Reconnect to try again.";log(message);publish();return;
        }
        if(converting||receiver!=null||!pending.isEmpty())throw new IOException("Recorder busy. Wait for the current action to finish.");
        switch(action){
            case "sync":deferSync=false;startSync();break;
            case "refresh": refresh();break;
            case "files":
                if(recordState!=0)throw new IOException("Stop recording and refresh device status first");
                directory=JwdProtocol.part(i.getStringExtra("dir"));files.clear();begin("files","Loading device files",20000);ble.send("APP&LIST&"+directory);break;
            case "start":
                if(recordState!=0)throw new IOException("Device status is unknown. Refresh it first.");
                if(RecorderService.active||RecorderService.finishing)throw new IOException("Finish the phone recording first.");
                if(live!=null&&!live.finished)throw new IOException("The previous transcript is finishing. Try again shortly.");live=null;requestLive=i.getBooleanExtra("live",false);if(requestLive&&store.token("access_token").isEmpty())throw new IOException("Sign in to use live transcription.");
                resetSync();deferSync=false;lastDraft="";syncTarget="";store.pendingDeviceRecord(address,"");
                begin("start","Waiting for recording to start",15000);ble.send("APP&STA");break;
            case "stop":
                if(recordState!=1&&recordState!=2)throw new IOException("Recording has not been confirmed. Refresh device status.");
                begin("stop","Waiting for the recorder to stop and save",15000);ble.send("APP&STO");break;
            case "pause":
                if(recordState!=1)throw new IOException("Recording has not been confirmed. Refresh device status.");
                begin("pause","Waiting for the recorder to pause",15000);ble.send("APP&PAU");break;
            case "resume":
                if(recordState!=2)throw new IOException("A paused recording has not been confirmed.");
                begin("resume","Waiting for the recorder to resume",15000);ble.send("APP&RESU");break;
            case "download": download(i);break;
        }
        publish();
    }
    private void scan(boolean compatibility)throws Exception{
        if(connected||converting||!pending.isEmpty())throw new IOException("Disconnect the current device or wait for verification to finish");
        if(adapter==null)throw new IOException("Bluetooth is unavailable");if(!adapter.isEnabled())throw new IOException("Turn on Bluetooth first");
        stopScan();cancelAutomaticConnection();found.clear();autoDiscovery=true;preferredRecorder=store.recorderAddress();scanning=true;compatibilityScanning=compatibility;
        message="Searching for your JWD recorder";
        if(compatibility){if(!adapter.startDiscovery()){scanning=false;compatibilityScanning=false;throw new IOException("Device discovery could not start. Try again.");}}
        else{scanner=adapter.getBluetoothLeScanner();if(scanner==null){scanning=false;throw new IOException("Bluetooth scanning is unavailable");}scanner.startScan(null,new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),scanCallback);}
        handler.postDelayed(scanStop,15000);handler.postDelayed(autoPick,4000);publish();
    }
    private final Runnable scanStop=()->{if(autoDiscovery)selectAutomaticRecorder();else{stopScan();publish();}};
    private final Runnable autoPick=()->{if(scanning&&autoDiscovery&&!found.isEmpty())selectAutomaticRecorder();};
    private void cancelAutomaticConnection(){autoDiscovery=false;autoProbing=false;autoQueue.clear();autoTried.clear();if(handler!=null)handler.removeCallbacks(autoPick);}
    private void selectAutomaticRecorder(){
        if(!autoDiscovery||autoProbing||!scanning)return;
        stopScan();autoQueue.clear();
        if(!preferredRecorder.isEmpty()){
            if(!found.containsKey(preferredRecorder))try{found.put(preferredRecorder,new JSONObject().put("address",preferredRecorder).put("name",store.recorderName()).put("rssi",-200).put("gatt_status","unknown"));}catch(Exception ignored){}
            autoQueue.add(preferredRecorder);
        }else{
            ArrayList<JSONObject> sorted=new ArrayList<>(found.values());
            sorted.sort((a,b)->Integer.compare(b.optInt("rssi",-200),a.optInt("rssi",-200)));
            for(JSONObject item:sorted)autoQueue.add(item.optString("address"));
        }
        nextAutomaticProbe();
    }
    private void nextAutomaticProbe(){
        if(!autoDiscovery||destroyed)return;
        while(!autoQueue.isEmpty()){
            String id=autoQueue.removeFirst();if(!autoTried.add(id))continue;
            JSONObject item=found.get(id);if(item==null)continue;
            try{
                handle(new Intent().setAction("probe").putExtra("address",id).putExtra("name",item.optString("name","JWD recorder")).putExtra("automatic",true));
                autoProbing=true;return;
            }catch(Exception e){autoProbing=false;}
        }
        autoDiscovery=false;
        message=preferredRecorder.isEmpty()?"No JWD recorder found. Wake your recorder and try again.":"Your last recorder is unavailable. Wake it up and try again.";publish();
    }
    private void automaticProbeFinished(boolean matches){
        if(!autoDiscovery||!autoProbing)return;
        autoProbing=false;
        if(!matches){nextAutomaticProbe();return;}
        try{
            // Persist before APP&SK, then reuse the same code after retries/restarts.
            if(store.deviceKey(address).isEmpty())store.deviceKey(address,JwdProtocol.newKey());
            autoDiscovery=false;autoQueue.clear();
            handle(new Intent().setAction("connect").putExtra("address",address).putExtra("name",deviceName).putExtra("automatic",true));
        }catch(Exception e){cancelAutomaticConnection();problem("The device code could not be saved. Try connecting again.");}
    }
    private final ScanCallback scanCallback=new ScanCallback(){
        @Override public void onScanResult(int type,ScanResult result){handler.post(()->{
            if(!scanning||compatibilityScanning)return;try{
                BluetoothDevice d=result.getDevice();String name=result.getScanRecord()==null?null:result.getScanRecord().getDeviceName();if(name==null)name=d.getName();
                boolean match=result.getScanRecord()!=null&&result.getScanRecord().getServiceUuids()!=null&&result.getScanRecord().getServiceUuids().contains(new ParcelUuid(JwdProtocol.SERVICE));
                recordFound(d,name,result.getRssi(),match,"ble_advertisement");
            }catch(Exception ignored){}
        });}
        @Override public void onScanFailed(int code){handler.post(()->{stopScan();problem("Bluetooth scan failed ("+code+"). Try again.");});}
    };
    private void recordFound(BluetoothDevice d,String name,int rssi,boolean match,String source){try{
        JSONObject previous=found.get(d.getAddress());if(name==null)name=d.getName();if(name==null&&previous!=null)name=previous.optString("name",null);if(name==null)name="Unnamed Bluetooth device";
        // Scan responses may omit UUIDs present in an earlier advertisement. Keep that evidence.
        match=match||previous!=null&&previous.optBoolean("jwd");boolean candidate=JwdProtocol.candidateName(name)||d.getAddress().equals(store.recorderAddress());
        if(!match&&!candidate)return;
        if(found.size()>=100&&previous==null){
            if(!match&&!candidate)return;String remove=null;for(Map.Entry<String,JSONObject> item:found.entrySet())if(!item.getValue().optBoolean("jwd")&&!item.getValue().optBoolean("name_match")){remove=item.getKey();break;}
            if(remove==null)return;found.remove(remove);
        }
        found.put(d.getAddress(),new JSONObject().put("name",name).put("address",d.getAddress()).put("rssi",rssi).put("jwd",match).put("name_match",candidate).put("scan_source",source).put("gatt_status",previous==null?"unknown":previous.optString("gatt_status","unknown")));publish();
        if(autoDiscovery&&scanning&&d.getAddress().equals(preferredRecorder))handler.post(this::selectAutomaticRecorder);
    }catch(Exception ignored){}}
    private void stopScan(){handler.removeCallbacks(scanStop);handler.removeCallbacks(autoPick);boolean cancelDiscovery=compatibilityScanning;scanning=false;compatibilityScanning=false;if(scanner!=null)try{scanner.stopScan(scanCallback);}catch(Exception ignored){}scanner=null;if(cancelDiscovery&&adapter!=null)try{adapter.cancelDiscovery();}catch(Exception ignored){}}
    @Override public void stage(String stage){
        connectionStage=stage;if(stage.equals("jwd_service_verified"))gattVerified=true;
        String label;
        switch(stage){case "discovering_services":label="Checking device services";break;case "jwd_service_verified":label="Recording service verified";break;case "requesting_mtu":label="Negotiating Bluetooth data size";break;case "subscribing_audio":label="Enabling audio notifications";break;case "subscribing_commands":label="Enabling command notifications";break;default:label="Bluetooth channels ready";}
        if(!pairingRequested)message=label;log(label);publish();
    }
    @Override public void serviceChecked(boolean matches,String reason){
        done("probe");connected=false;authorized=false;recordState=-1;
        JSONObject item=found.get(address);if(item!=null)try{item.put("gatt_status",matches?"verified":"unsupported");}catch(JSONException ignored){}
        message=reason;log(reason);publish();automaticProbeFinished(matches);
    }
    @Override public void ready(){
        connected=true;connectionStage="app_key_auth";try{begin("auth","Connected. Checking device key…",15000);ble.send("APP&SK&"+store.deviceKey(address));publish();}catch(Exception e){problem("The key could not be read. Enter the original key again.");ble.close();connected=false;publish();}
    }
    @Override public void closed(String reason){
        stopLive(false);
        abortTransfer();syncFailed(reason);connected=false;authorized=false;recordState=-1;pending="";operation++;if(autoProbing){autoProbing=false;nextAutomaticProbe();return;}message=(pairingRequested?"Android requested a PIN. Cancel the prompt and export diagnostics. ":"")+reason;log(reason);publish();
    }
    private void begin(String kind,String text,long timeout){
        pending=kind;message=text;long generation=++operation;
        handler.postDelayed(()->{
            if(generation!=operation||pending.isEmpty()||destroyed)return;
            if(pending.equals("download")){transferFailed("Transfer did not start in time. Reconnect and try again.");return;}
            String old=pending;pending="";message="Recorder did not confirm the action ("+old+"). Refresh device status or reconnect.";
            if(syncing)syncFailed(message);
            if(old.equals("auth")||old.equals("start")||old.equals("stop")||old.equals("probe")||old.equals("connect")){stopLive(false);ble.close();authorized=false;connected=false;recordState=-1;}
            log(message);publish();if(old.equals("probe"))automaticProbeFinished(false);
        },timeout);
    }
    private void done(String kind){if(pending.equals(kind)){pending="";operation++;}}
    private void refresh()throws Exception{
        dirs.clear();files.clear();directory="";begin("dirs","Loading device status and folders",25000);
        ble.send("APP&FW");ble.send("APP&BAT");ble.send("APP&SPACE");ble.send("APP&RT");ble.send("APP&LIST_DIRS");
    }
    @Override public void command(byte[] data){
        try{for(String value:JwdProtocol.replies(data))if(!value.isEmpty())reply(value.trim());}
        catch(Exception e){if(receiver!=null||pending.equals("download"))transferFailed("Invalid device response: "+e.getMessage());else{syncFailed(e.getMessage());problem("Invalid device response: "+e.getMessage());}}
    }
    private void reply(String value)throws Exception{
        String[] p=value.split("&",-1);if(p.length<2)return;String type=p[1];
        if(type.equals("SK")){
            if(p.length<3)return;
            if(p[2].equals("OK")&&pending.equals("auth")){
                done("auth");authorized=true;if(found.containsKey(address))found.get(address).put("key_rejected",false);store.rememberRecorder(address,deviceName);syncTarget=store.pendingDeviceRecord(address);log("Recorder authorized");ble.send("APP&T&"+new SimpleDateFormat("yyyyMMddHHmmss",Locale.ROOT).format(new Date()));refresh();
            }else if(p[2].equals("ERR")){abortTransfer();ble.close();connected=false;authorized=false;pending="";operation++;if(found.containsKey(address))found.get(address).put("key_rejected",true);cancelAutomaticConnection();message="Device key was rejected. Use the original key; the recorder was not reset.";log(message);}
            publish();return;
        }
        if(!authorized)return;
        switch(type){
            case "FW":if(p.length>2)firmware=p[2];break;
            case "BAT":if(p.length>2){int level=Integer.parseInt(p[2]);battery=(level>=0&&level<=100?level+"%":"Battery not received")+(p.length>3&&p[3].equals("F")?" · Fully charged":(p.length>3&&p[3].equals("C")||level==200)?" · Charging":"");}break;
            case "SPA":if(p.length>3)capacity="Available: "+p[2]+" / "+p[3]+" MB";break;
            case "RT":
                if(p.length==3&&p[2].equals("0")){stopped();}
                else if(p.length>=4&&!(recordState==2&&p[2].equals(recordName))){recording(p[2],Long.parseLong(p[3]));}break;
            case "STE":if(p.length>2){if(Integer.parseInt(p[2])==1)recordState=1;else stopped();}break;
            case "STA":if(p.length>2){recording(p[2],0);done("start");message="Recorder is recording";log("Recording start confirmed");}break;
            case "PAUSE":
                if(recordState==1){recordState=2;recordPausedAt=SystemClock.elapsedRealtime();if(live!=null)live.transcriber.pause(true);}
                done("pause");message="Recording paused";break;
            case "RESUME":
                if(recordState==2){recordPausedTotal+=SystemClock.elapsedRealtime()-recordPausedAt;recordPausedAt=0;recordState=1;if(live!=null)live.transcriber.pause(false);}
                done("resume");message="Recorder is recording";break;
            case "STO":stopped();done("stop");message="Saved on recorder · Syncing to this phone";log("Recording stop confirmed");scheduleSync();break;
            case "AUTO":if(p.length>2&&p[2].equals("STO")){stopped();scheduleSync();}else if(p.length>3&&p[2].equals("STA"))recording(p[3],0);break;
            case "DISK":case "REC":if(value.endsWith("&ERR")){pending="";operation++;recordState=-1;problem(type.equals("DISK")?"Recorder storage is full":"The recorder reported an audio error");}break;
            case "DIRS":if(pending.equals("dirs")&&p.length>2){String dir=JwdProtocol.part(p[2]);if(!dirs.contains(dir))dirs.add(dir);}break;
            case "DIRS_SUM":if(pending.equals("dirs")&&p.length>2){int total=Integer.parseInt(p[2]);done("dirs");if(total!=dirs.size()){dirs.clear();throw new IOException("Folder list is incomplete. Refresh it.");}Collections.sort(dirs,Collections.reverseOrder());message="Recorder connected · "+dirs.size()+" folders";if(syncing)nextSyncDirectory();else if(!deferSync)scheduleSync();}break;
            case "F":if(pending.equals("files")&&p.length>=5&&directory.equals(p[2])){String name=JwdProtocol.part(p[3]);boolean exists=false;for(JSONObject file:files)if(file.optString("name").equals(name))exists=true;if(!exists)files.add(new JSONObject().put("name",name).put("seconds",Long.parseLong(p[4])));}break;
            case "LIST":if(pending.equals("files")&&p.length>2){int total=Integer.parseInt(p[2]);done("files");if(total!=files.size()){files.clear();throw new IOException("File list is incomplete. Load it again.");}Collections.sort(files,(a,b)->b.optString("name").compareTo(a.optString("name")));message="Loaded "+files.size()+" recordings";if(syncing){for(JSONObject file:files)if(!store.deviceRecordSynced(address,directory,file.optString("name"),file.optLong("seconds")))syncFiles.add(new JSONObject(file.toString()).put("dir",directory));nextSyncDirectory();}}break;
            case "U":
                if(p.length>2&&p[2].equals("ERR")){transferFailed("The recorder could not read this file. Stop recording and try again.");break;}
                if(pending.equals("download")&&p.length>2){
                    long length=Long.parseLong(p[2]);if(raw.getParentFile().getUsableSpace()<length*10+10485760)throw new IOException("Not enough phone storage to receive and decode this file");
                    receiver=new JwdProtocol.Receiver(raw,length);endSeen=false;done("download");lastData=SystemClock.elapsedRealtime();message="Receiving audio over Bluetooth";
                    wake.acquire(65*60*1000L);handler.postDelayed(transferWatch,1000);log("Transfer started, declared bytes: "+length);
                }break;
            case "OFF":if(receiver!=null){receiver.end(p.length>2?p[2]:"");endSeen=true;maybeFinish();}break;
            case "SHUT":if(receiver!=null)transferFailed("Transfer interrupted. Reconnect and try again.");break;
        }
        publish();
    }
    private void recording(String name,long seconds){
        if(receiver!=null||pending.equals("download")){transferFailed("Recording started during transfer. Stop recording before transferring files.");return;}
        if(!name.equals(recordName)){lastDraft="";syncTarget=name;store.pendingDeviceRecord(address,name);syncError="";}
        syncing=false;syncFiles.clear();
        if(requestLive&&(live==null||live.finished)&&!store.token("access_token").isEmpty()){live=new JwdLiveSession(store,name);wake.acquire(65*60*1000L);}
        recordState=1;recordName=name;recordStart=SystemClock.elapsedRealtime()-Math.max(0,seconds)*1000;recordPausedAt=0;recordPausedTotal=0;
    }
    private void stopped(){
        boolean wasRecording=recordState==1||recordState==2;
        if(!recordName.isEmpty()){syncTarget=recordName;store.pendingDeviceRecord(address,recordName);}
        stopLive(true);recordState=0;recordName="";
        if(wasRecording)scheduleSync();
    }
    private void resetSync(){syncing=false;syncFiles.clear();syncDirectory=0;syncRetry=0;syncError="";}
    private void syncFailed(String error){syncing=false;syncFiles.clear();syncError=error==null?"Reconnect to sync the recording.":error;}
    private void scheduleSync(){
        handler.removeCallbacks(syncLater);handler.postDelayed(syncLater,1500);
    }
    private final Runnable syncLater=()->{if(authorized&&recordState==0&&!deferSync&&!syncing&&pending.isEmpty()&&receiver==null&&!converting)try{startSync();}catch(Exception e){syncFailed(e.getMessage());problem(e.getMessage());}};
    private void startSync()throws Exception{
        if(store.scope().isEmpty()||!store.recordingOptionsSet()){message="Saved on recorder. Sign in and set recording preferences to sync automatically.";publish();return;}
        if(recordState!=0||!pending.isEmpty()||receiver!=null||converting)return;
        syncing=true;syncScope=store.scope();syncError="";syncFiles.clear();syncDirectory=0;refresh();publish();
    }
    private void nextSyncDirectory()throws Exception{
        if(!syncing||recordState!=0)return;
        if(!syncScope.equals(store.scope())){syncFailed("Sign in to the original account to continue syncing.");return;}
        if(syncDirectory<dirs.size()){
            directory=dirs.get(syncDirectory++);files.clear();begin("files","Checking for recordings to sync",20000);ble.send("APP&LIST&"+directory);return;
        }
        // Prioritize the just-stopped file, never substitute a different recording for it.
        syncFiles.sort((a,b)->Boolean.compare(matchesTarget(b.optString("name")),matchesTarget(a.optString("name"))));
        nextSyncFile();
    }
    private boolean matchesTarget(String name){return !syncTarget.isEmpty()&&(name.equals(syncTarget)||name.replaceFirst("\\.[^.]+$","").equals(syncTarget.replaceFirst("\\.[^.]+$","")));}
    private void nextSyncFile()throws Exception{
        if(!syncing||recordState!=0)return;
        if(!syncScope.equals(store.scope())){syncFailed("Account changed. Reconnect to sync.");return;}
        while(!syncFiles.isEmpty()){
            JSONObject file=syncFiles.remove(0);long seconds=file.optLong("seconds");
            if(seconds<=0||seconds>3600){syncError="A device file cannot be synced automatically. Check Device recordings (60-minute recorder limit).";continue;}
            downloadFile(file.optString("dir"),file.optString("name"),seconds);return;
        }
        syncing=false;
        if(!syncTarget.isEmpty()&&lastDraft.isEmpty()){
            if(syncRetry++<2){message="Waiting for the recorder to finish saving…";handler.postDelayed(syncLater,3000);}
            else{syncError="The saved file is not available yet. Retry sync or check Device recordings.";message=syncError;}
        }else{syncRetry=0;message=syncError.isEmpty()?"Recordings synced · Local copies kept":syncError;}
        publish();
    }
    private void stopLive(boolean confirmed){requestLive=false;if(live!=null&&!live.finished)live.stop(confirmed);if(receiver==null&&!converting)releaseWake();}
    private void download(Intent i)throws Exception{
        if(store.scope().isEmpty()||store.token("access_token").isEmpty())throw new IOException("Sign in first. Imported recordings are saved to that account on this phone.");
        if(recordState!=0)throw new IOException("Stop recording and refresh device status first");
        String name=JwdProtocol.part(i.getStringExtra("file")),dir=JwdProtocol.part(i.getStringExtra("dir"));long seconds=-1;
        for(JSONObject f:files)if(directory.equals(dir)&&f.optString("name").equals(name))seconds=f.optLong("seconds");
        if(seconds<0)throw new IOException("Refresh the device file list");if(seconds>3600)throw new IOException("Recordings must be under 60 minutes. For a connection test, record 10–30 seconds.");
        downloadFile(dir,name,seconds);
    }
    private void downloadFile(String dir,String name,long seconds)throws Exception{
        if(store.scope().isEmpty())throw new IOException("Sign in before syncing to this phone.");
        downloadName=JwdProtocol.part(name);downloadDir=JwdProtocol.part(dir);downloadSeconds=seconds;downloadScope=store.scope();raw=new File(store.folder(),"jwd-"+UUID.randomUUID()+".raw");
        begin("download","Waiting for transfer to start",20000);ble.send("APP&U&"+dir+"&"+name);log("Device file requested");
    }
    @Override public void audio(byte[] data){
        if(receiver==null){if(recordState==1&&live!=null)live.feed(data);return;}try{receiver.write(data);lastData=SystemClock.elapsedRealtime();maybeFinish();if(lastData-lastPublish>400)publish();}catch(Exception e){transferFailed(e.getMessage());}
    }
    private final Runnable transferWatch=new Runnable(){public void run(){
        if(receiver==null)return;
        if(SystemClock.elapsedRealtime()-lastData>(endSeen?5000:30000)){transferFailed("File transfer timed out or is incomplete. No uploadable file was created.");return;}
        handler.postDelayed(this,1000);
    }};
    private void maybeFinish()throws Exception{
        if(receiver==null||!receiver.complete())return;
        String verification=receiver.finish();receiver=null;handler.removeCallbacks(transferWatch);converting=true;pending="";
        String identity=downloadScope,mac=address,dir=downloadDir,name=downloadName;long seconds=downloadSeconds;File source=raw;raw=null;
        message="File received. Verifying and decoding audio…";log(verification.equals("crc32_verified")?"Checksum verified":"Checksum unavailable. File length verified.");publish();
        decoder.execute(()->{
            try{
                if(!identity.equals(store.scope()))throw new IOException("The account changed. The original file was kept without adding it to another account.");
                JSONObject draft=JwdAudio.importVerified(store,source,mac,dir,name,seconds,verification,percent->handler.post(()->{if(!destroyed){message="Decoding audio "+percent+"%";publish();}}));
                String notes=store.recorderNotes(mac,name);if(!notes.isEmpty()){draft.put("notes",notes);store.save(draft);}
                store.deviceRecordSynced(mac,dir,name,seconds,draft.optString("id"));
                try{UploadQueue.saved(this,draft);}catch(Exception ignored){/* The verified local draft remains available for manual retry. */}
                source.delete();handler.post(()->{converting=false;releaseWake();if(syncTarget.isEmpty()&&lastDraft.isEmpty()||matchesTarget(name)){lastDraft=draft.optString("id");syncTarget="";store.pendingDeviceRecord(mac,"");}message="Saved on this phone"+(verification.equals("length_only")?" · Device checksum unavailable":" · Checksum verified");log(message);publish();if(syncing)try{nextSyncFile();}catch(Exception e){syncFailed(e.getMessage());problem(e.getMessage());}});
            }catch(Exception e){handler.post(()->{converting=false;releaseWake();syncFailed(e.getMessage());problem("Audio could not finish syncing: "+e.getMessage()+". Original audio is kept.");});}
        });
    }
    private void transferFailed(String reason){abortTransfer();syncFailed(reason);ble.close();authorized=false;connected=false;recordState=-1;pending="";operation++;problem(reason);}
    private void abortTransfer(){
        handler.removeCallbacks(transferWatch);if(receiver!=null)try{receiver.close();}catch(Exception ignored){}receiver=null;
        if(raw!=null){raw.delete();raw=null;}if(!converting)releaseWake();
    }
    private void releaseWake(){if(wake!=null&&wake.isHeld())wake.release();}
    private void log(String s){logs.add(new SimpleDateFormat("HH:mm:ss",Locale.CHINA).format(new Date())+" "+s);while(logs.size()>60)logs.remove(0);}
    private void problem(String reason){message=reason==null?"Action failed. Try again.":reason;log(message);publish();}
    /** A device event anchors the clock; UI ticks must not depend on further BLE replies. */
    static long elapsed(JSONObject state,long now){
        long value=state.optLong("elapsed_ms");
        if(state.optInt("record_state",-1)==1&&state.optBoolean("connected")&&state.optBoolean("authorized")&&state.has("elapsed_at"))
            value+=Math.max(0,now-state.optLong("elapsed_at"));
        return Math.max(0,value);
    }
    private void publish(){
        if(destroyed)return;try{
            JSONObject s=new JSONObject().put("message",message).put("connection_stage",connectionStage).put("jwd_service_verified",gattVerified).put("system_pairing_requested",pairingRequested).put("system_pairing_variant",pairingVariant).put("system_pairing_stage",pairingStage).put("scanning",scanning).put("compatibility_scan",compatibilityScanning).put("connected",connected).put("authorized",authorized).put("name",deviceName).put("address",address).put("battery",battery).put("firmware",firmware).put("capacity",capacity).put("record_state",recordState).put("record_name",recordName).put("record_start",recordStart).put("directory",directory).put("pending",pending).put("converting",converting).put("last_draft",lastDraft).put("busy",converting||receiver!=null||!pending.isEmpty()).put("receiving",receiver!=null||pending.equals("download")).put("received",receiver==null?0:receiver.received()).put("expected",receiver==null?0:receiver.expected).put("devices",verifiedDevices()).put("dirs",new JSONArray(dirs)).put("files",new JSONArray(files)).put("log",new JSONArray(logs));
            s.put("syncing",syncing).put("sync_target",syncTarget).put("sync_error",syncError).put("busy",syncing||converting||receiver!=null||!pending.isEmpty());
            long now=SystemClock.elapsedRealtime();
            long elapsed=recordState>0?Math.max(0,(recordState==2?recordPausedAt:now)-recordStart-recordPausedTotal)
                :recordName.isEmpty()?0:elapsed(new JSONObject(snapshot),now);
            s.put("elapsed_ms",elapsed).put("elapsed_at",now);
            snapshot=s.toString();if(now-lastPublish>500){((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(13,notification(message));}lastPublish=now;
        }catch(Exception ignored){}
    }
    private JSONArray verifiedDevices(){
        JSONArray result=new JSONArray();for(JSONObject item:found.values())if(item.optString("gatt_status").equals("verified"))result.put(item);return result;
    }
    @Override public void onDestroy(){
        try{unregisterReceiver(pairingReceiver);}catch(IllegalArgumentException ignored){}
        active=false;handler.post(()->{stopLive(false);stopScan();abortTransfer();ble.close();connected=false;authorized=false;recordState=-1;pending="";operation++;publish();destroyed=true;releaseWake();thread.quitSafely();});
        decoder.shutdownNow();super.onDestroy();
    }
}
