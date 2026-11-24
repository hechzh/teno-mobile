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
    static volatile boolean accountClosing;
    static final java.util.concurrent.atomic.AtomicLong sessionEpoch=new java.util.concurrent.atomic.AtomicLong();
    private long connectionEpoch;
    private String connectionOwner="";
    private boolean signedIn(){return !accountClosing&&!store.scope().isEmpty()&&!store.token("access_token").isEmpty();}
    private boolean sessionCurrent(){return signedIn()&&connectionEpoch==sessionEpoch.get()&&connectionOwner.equals(store.scope());}
    public static volatile String snapshot="{}";
    private HandlerThread thread;private Handler handler;private JwdTransport ble;private Store store;
    private final ExecutorService decoder=Executors.newSingleThreadExecutor();
    private BluetoothLeScanner scanner;private BluetoothAdapter adapter;private PowerManager.WakeLock wake;
    private boolean scanning,compatibilityScanning,connected,authorized,converting,destroyed;
    private boolean autoDiscovery,autoProbing,manualVerifiedSelection;
    private ScanCallback currentScan;
    private final ArrayDeque<String> autoQueue=new ArrayDeque<>();
    private final HashSet<String> autoTried=new HashSet<>();
    private String preferredRecorder="";
    private String compatibilityToken="", originalForConnection="";
    private String selectedForPairing="",selectionOwner="";
    private long selectionEpoch=-1;
    private boolean hardwareReadOnLink;
    static final String REGISTRATION_UNAVAILABLE="This recorder did not return a hardware ID. Recording and syncing are still available.";
    static final String IDENTITY_TIMEOUT="The recorder connected, but did not return its hardware ID. Check the physical recorder before authorizing it.";
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
    private RecorderOwnership ownership;
    private boolean ownershipInventory,ownershipReading,ownershipReconnect;
    private int inventoryDirectory;
    private final ArrayList<String> inventoryEntries=new ArrayList<>();
    private final ArrayDeque<JSONObject> inventoryFiles=new ArrayDeque<>();
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public void onCreate(){
        super.onCreate();store=new Store(this);thread=new HandlerThread("Teno-JWD");thread.start();handler=new Handler(thread.getLooper());ble=new JwdBle(this,handler,this);
        ownership=new RecorderOwnership(store,handler,new RecorderOwnership.Port(){
            public void sendKey(String key){try{
                if(!sessionCurrent()||!connected||!gattVerified)throw new IOException("Confirm the connected recorder first.");
                begin("auth","Connected. Checking device key…",15000);ble.send("APP&SK&"+key);
                if(ownership.authorizingDaily()){
                    long attempt=operation;
                    handler.postDelayed(()->{
                        if(!destroyed&&sessionCurrent()&&connected&&!authorized&&operation==attempt&&pending.equals("auth"))
                            try{ble.send("APP&SK&"+key);}catch(Exception e){ownership.fail(e.getMessage());}
                    },7000);
                }
            }catch(Exception e){ownership.fail(e.getMessage());}}
            public void verifyIdentity(){readIdentity("verified_identity");}
            public void reconnect(){reconnectOwnership();}
            public void inventory(){try{authorized=true;deferSync=true;ownershipInventory=true;inventoryDirectory=0;inventoryEntries.clear();inventoryFiles.clear();refresh();}catch(Exception e){problem(e.getMessage());}}
            public void unbind(){try{ownershipReconnect=true;begin("rotate","Updating recorder authorization",20000);ble.send("APP&BLE&OFF");}catch(Exception e){ownershipReconnect=false;problem(e.getMessage());}}
            public void ready(){try{authorized=true;connectionStage="gatt_ready";deferSync=false;autoDiscovery=false;syncTarget=store.pendingDeviceRecord(address);ble.send("APP&T&"+new SimpleDateFormat("yyyyMMddHHmmss",Locale.ROOT).format(new Date()));refresh();}catch(Exception e){problem(e.getMessage());}}
            public void changed(){message=ownership.message;publish();}
            public void close(String text){originalForConnection="";clearCompatibilityOffer();ownershipReconnect=false;ble.close();connected=false;authorized=false;pending="";operation++;message=text;publish();}
            public void seek(){ble.close();connected=false;authorized=false;pending="";operation++;if(autoDiscovery){nextAutomaticProbe();}else try{scan(false);}catch(Exception e){problem(e.getMessage());}}
        });
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
        if(!Arrays.asList("disconnect","stop","cancel").contains(action)){
            if(!signedIn()||i.getLongExtra("session_epoch",sessionEpoch.get())!=sessionEpoch.get())throw new IOException("Sign in to connect your recorder.");
            if(Arrays.asList("scan","scan_compat","connect","probe","ownership_operation").contains(action)){connectionEpoch=sessionEpoch.get();connectionOwner=store.scope();}
        }
        if(action.equals("ownership_register")){
            if(!sessionCurrent()||!authorized||!connected||!gattVerified||!"authorized".equals(ownership.state)
                    ||!pending.isEmpty()||syncing||converting||receiver!=null||recordState!=0||RecorderService.active||RecorderService.finishing)
                throw new IOException("Finish recording and syncing before registering this recorder.");
            readIdentity("register_identity");return;
        }
        if(action.equals("ownership_claim")){if(!connected||!hardwareReadOnLink||!pending.isEmpty())throw new IOException("Confirm the connected recorder first.");ownership.claim(i.getStringExtra("original_key")==null?"":i.getStringExtra("original_key"),i.getBooleanExtra("confirm",false));return;}
        if(action.equals("ownership_identity_compat")){
            if(!sessionCurrent()||!connected||!gattVerified||authorized||!pending.isEmpty()||!i.getBooleanExtra("confirm",false)
                    ||compatibilityToken.isEmpty()||!compatibilityToken.equals(i.getStringExtra("compat_token"))
                    ||!address.equals(i.getStringExtra("address")))throw new IOException("Confirm the connected recorder first.");
            String selected=i.getStringExtra("selected_hardware_id");
            if(selected!=null&&!selected.isEmpty()&&(!selected.equals(selectedForPairing)||selectionEpoch!=connectionEpoch||!connectionOwner.equals(selectionOwner)))
                throw new IOException("Confirm the connected recorder first.");
            ownership.compatibility(address,deviceName,selected);clearCompatibilityOffer();publish();return;
        }
        if(action.equals("ownership_select")){
            if(recordState>0||converting||receiver!=null||syncing)throw new IOException("Finish recording and syncing before switching recorders.");
            clearCompatibilityOffer();
            ownership.cancel();ownershipReconnect=false;ble.close();connected=false;authorized=false;pending="";operation++;
            selectedForPairing=RecorderOwnership.canonical(i.getStringExtra("hardware_id"));selectionOwner=store.scope();selectionEpoch=sessionEpoch.get();
            store.selectRecorder(selectedForPairing);message="Recorder selected";publish();return;
        }
        if(action.equals("ownership_operation")){
            if(recordState>0||converting||receiver!=null||syncing||RecorderService.active||RecorderService.finishing)throw new IOException("Finish recording and syncing before transferring this recorder.");
            deferSync=true;ownership.start(i.getStringExtra("operation_id"));return;
        }
        if(action.equals("prepare_recording")){deferSync=true;syncing=false;syncFiles.clear();publish();return;}
        if(action.equals("resume_sync")){deferSync=false;if(authorized&&recordState==0&&pending.isEmpty()&&receiver==null&&!converting)startSync();return;}
        if(action.equals("disconnect")){cancelAutomaticConnection();if(converting)throw new IOException("Wait for the decoded file to finish saving before disconnecting");clearCompatibilityOffer();selectedForPairing="";ownership.cancel();ownershipReconnect=false;releaseRecordingWake();stopScan();abortTransfer();resetSync();ble.close();connected=false;authorized=false;recordState=-1;pending="";operation++;message="Disconnected. Check the recorder: it may still be recording.";publish();stopSelf();return;}
        if(action.equals("scan")||action.equals("scan_compat")){scan(action.equals("scan_compat"));return;}
        if(action.equals("probe")){
            if(!i.getBooleanExtra("automatic",false))cancelAutomaticConnection();
            if(connected||converting||receiver!=null||!pending.isEmpty())throw new IOException("Disconnect the current device or wait for verification to finish");
            String candidate=i.getStringExtra("address");if(!BluetoothAdapter.checkBluetoothAddress(candidate))throw new IOException("Invalid Bluetooth address");
            if(adapter==null||!adapter.isEnabled())throw new IOException("Turn on Bluetooth");
            ownership.connectionAttempt();stopScan();address=candidate;deviceName=i.getStringExtra("name");if(deviceName==null)deviceName="Unnamed device";
            pairingRequested=false;pairingVariant=-1;pairingStage="";gattVerified=false;connectionStage="connecting";
            authorized=false;recordState=-1;firmware="";battery="Not received";capacity="";dirs.clear();files.clear();directory="";
            begin("probe","Verifying recorder protocol",27000);log("Checking device services");ble.probe(adapter.getRemoteDevice(address));publish();return;
        }
        if(action.equals("connect")){
            if(!i.getBooleanExtra("automatic",false))cancelAutomaticConnection();
            if(converting||receiver!=null)throw new IOException("Finish or cancel the current transfer first");
            JSONObject chosen=found.get(i.getStringExtra("address"));
            manualVerifiedSelection=!i.getBooleanExtra("automatic",false)&&chosen!=null&&"verified".equals(chosen.optString("gatt_status"));
            String original=i.getStringExtra("original_key");
            if(original!=null&&(!manualVerifiedSelection||!JwdProtocol.validKey(original)||!chosen.optBoolean("key_rejected")))
                throw new IOException("Check the recorder service and its original key first.");
            originalForConnection=original==null?"":original;
            ownership.connectionAttempt();lastDraft="";syncTarget="";
            stopScan();ble.close();abortTransfer();resetSync();deferSync=i.getBooleanExtra("defer_sync",false);operation++;pending="";authorized=false;connected=false;recordState=-1;recordName="";firmware="";capacity="";battery="Not received";dirs.clear();files.clear();directory="";
            address=i.getStringExtra("address");deviceName=i.getStringExtra("name");if(deviceName==null)deviceName="JWD recorder";
            pairingRequested=false;pairingVariant=-1;pairingStage="";gattVerified=false;connectionStage="connecting";
            if(!BluetoothAdapter.checkBluetoothAddress(address))throw new IOException("Invalid Bluetooth address");
            if(adapter==null||!adapter.isEnabled())throw new IOException("Turn on Bluetooth");
            begin("connect","Connecting automatically",27000);log("Connecting recorder");ble.connect(adapter.getRemoteDevice(address));handler.postDelayed(()->{if(deferSync){deferSync=false;if(authorized&&recordState==0&&pending.isEmpty())try{startSync();}catch(Exception e){syncFailed(e.getMessage());}}},45000);publish();return;
        }
        if(!authorized||ownership.blocked())throw new IOException("Connect and authorize the recorder first");
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
        stopScan();cancelAutomaticConnection();found.clear();
        if(Build.VERSION.SDK_INT<31&&android.provider.Settings.Secure.getInt(getContentResolver(),
                android.provider.Settings.Secure.LOCATION_MODE,0)==0)
            throw new IOException("Turn on Location in Android settings to scan for nearby devices.");
        autoDiscovery=true;preferredRecorder=store.recorderAddress();scanning=true;compatibilityScanning=compatibility;
        connectionStage=compatibility?"sdk_discovery":"ble_scan";
        message=compatibility?"Compatibility scan · 15 seconds":"Searching for your JWD recorder";
        try{
            if(compatibility){
                if(!adapter.startDiscovery())throw new IOException("Device discovery could not start. Try again.");
            }else{
                scanner=adapter.getBluetoothLeScanner();
                if(scanner==null)throw new IOException("Bluetooth scanning is unavailable");
                currentScan=new DiscoveryCallback();
                scanner.startScan(null,new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),currentScan);
            }
        }catch(Exception e){stopScan();cancelAutomaticConnection();throw e;}
        handler.postDelayed(scanStop,15000);publish();
    }
    private final Runnable scanStop=()->{if(autoDiscovery)selectAutomaticRecorder();else{stopScan();publish();}};
    private void cancelAutomaticConnection(){autoDiscovery=false;autoProbing=false;autoQueue.clear();autoTried.clear();}
    private void selectAutomaticRecorder(){
        if(!sessionCurrent()||!autoDiscovery||autoProbing||!scanning)return;
        stopScan();autoQueue.clear();
        ArrayList<JSONObject> sorted=new ArrayList<>(found.values());
        sorted.sort(Comparator.comparing((JSONObject row)->!row.optBoolean("jwd"))
                .thenComparing((a,b)->Integer.compare(b.optInt("rssi",-200),a.optInt("rssi",-200))));
        if(found.containsKey(preferredRecorder))autoQueue.add(preferredRecorder);
        for(JSONObject item:sorted){
            if(item.optBoolean("jwd")||item.optBoolean("name_match")||JwdProtocol.candidateName(item.optString("name")))
                autoQueue.add(item.optString("address"));
        }
        if(!preferredRecorder.isEmpty()&&!found.containsKey(preferredRecorder)){
            try{found.put(preferredRecorder,new JSONObject().put("address",preferredRecorder).put("name",store.recorderName())
                    .put("rssi",-200).put("gatt_status","unknown").put("scan_source","remembered"));}catch(JSONException ignored){}
            autoQueue.add(preferredRecorder);
        }
        nextAutomaticProbe();
    }
    private void nextAutomaticProbe(){
        if(!sessionCurrent()||!autoDiscovery||destroyed)return;
        while(!autoQueue.isEmpty()){
            String id=autoQueue.removeFirst();if(!autoTried.add(id))continue;
            JSONObject item=found.get(id);if(item==null)continue;
            try{
                handle(new Intent().setAction("probe").putExtra("address",id).putExtra("name",item.optString("name","JWD recorder")).putExtra("automatic",true));
                autoProbing=true;return;
            }catch(Exception e){autoProbing=false;}
        }
        autoDiscovery=false;
        connectionStage="scan_complete";
        if(!found.isEmpty()&&autoTried.isEmpty())message="Nearby devices found. Check the recorder service.";
        else if(!autoTried.isEmpty()&&found.get(address)!=null&&!found.get(address).optString("probe_error").isEmpty())
            message=found.get(address).optString("probe_error");
        else message=preferredRecorder.isEmpty()?"No JWD recorder found. Wake your recorder and try again.":"Your last recorder is unavailable. Wake it up and try again.";
        publish();
    }
    private void automaticProbeFinished(boolean matches){
        if(!sessionCurrent()||!autoDiscovery||!autoProbing)return;
        autoProbing=false;
        if(!matches){nextAutomaticProbe();return;}
        try{
            handle(new Intent().setAction("connect").putExtra("address",address).putExtra("name",deviceName).putExtra("automatic",true));
        }catch(Exception e){cancelAutomaticConnection();problem(e.getMessage());}
    }
    private final class DiscoveryCallback extends ScanCallback{
        @Override public void onScanResult(int type,ScanResult result){handler.post(()->{
            if(this!=currentScan||!scanning||result==null||!sessionCurrent())return;try{
                BluetoothDevice d=result.getDevice();String name=result.getScanRecord()==null?null:result.getScanRecord().getDeviceName();
                boolean match=result.getScanRecord()!=null&&result.getScanRecord().getServiceUuids()!=null&&result.getScanRecord().getServiceUuids().contains(new ParcelUuid(JwdProtocol.SERVICE));
                recordFound(d,name,result.getRssi(),match,"ble_advertisement");
            }catch(SecurityException e){stopScan();cancelAutomaticConnection();problem("Allow Nearby devices permission in Android settings.");}
        });}
        @Override public void onBatchScanResults(List<ScanResult> results){for(ScanResult result:results)onScanResult(0,result);}
        @Override public void onScanFailed(int code){handler.post(()->{if(this!=currentScan)return;stopScan();cancelAutomaticConnection();problem("Bluetooth scan failed ("+code+"). Try again.");});}
    }
    private void recordFound(BluetoothDevice d,String name,int rssi,boolean match,String source){try{
        JSONObject previous=found.get(d.getAddress());if(name==null||name.isEmpty())name=d.getName();
        if((name==null||name.isEmpty())&&previous!=null)name=previous.optString("name",null);
        if(name==null||name.isEmpty())name="Unnamed Bluetooth device";
        // Scan responses may omit UUIDs present in an earlier advertisement. Keep that evidence.
        match=match||previous!=null&&previous.optBoolean("jwd");boolean candidate=JwdProtocol.candidateName(name)||previous!=null&&previous.optBoolean("name_match")||d.getAddress().equals(preferredRecorder);
        if(found.size()>=100&&previous==null){
            if(!match&&!candidate)return;String remove=null;for(Map.Entry<String,JSONObject> item:found.entrySet())if(!item.getValue().optBoolean("jwd")&&!item.getValue().optBoolean("name_match")){remove=item.getKey();break;}
            if(remove==null)return;found.remove(remove);
        }
        if(rssi==127)rssi=-200;
        if(previous!=null&&name.equals(previous.optString("name"))&&match==previous.optBoolean("jwd")
                &&candidate==previous.optBoolean("name_match")&&Math.abs(rssi-previous.optInt("rssi",-200))<8)return;
        found.put(d.getAddress(),new JSONObject().put("name",name).put("address",d.getAddress()).put("rssi",rssi).put("jwd",match).put("name_match",candidate).put("scan_source",source).put("gatt_status","unknown"));publish();
    }catch(SecurityException e){stopScan();cancelAutomaticConnection();problem("Allow Nearby devices permission in Android settings.");}catch(JSONException ignored){}}
    private void stopScan(){handler.removeCallbacks(scanStop);boolean cancelDiscovery=compatibilityScanning;scanning=false;compatibilityScanning=false;if(scanner!=null&&currentScan!=null)try{scanner.stopScan(currentScan);}catch(Exception ignored){}scanner=null;currentScan=null;if(cancelDiscovery&&adapter!=null)try{adapter.cancelDiscovery();}catch(Exception ignored){}}
    @Override public void stage(String stage){
        connectionStage=stage;if(stage.equals("jwd_service_verified"))gattVerified=true;
        String label;
        switch(stage){case "discovering_services":label="Checking device services";break;case "jwd_service_verified":label="Recording service verified";break;case "requesting_mtu":label="Negotiating Bluetooth data size";break;case "subscribing_audio":label="Enabling audio notifications";break;case "subscribing_commands":label="Enabling command notifications";break;default:label="Bluetooth channels ready";}
        if(!pairingRequested)message=label;log(label);publish();
    }
    @Override public void serviceChecked(boolean matches,String reason){
        done("probe");connected=false;authorized=false;recordState=-1;
        rememberProbe(matches?"verified":"unsupported",matches?"":reason);
        message=reason;log(reason);publish();automaticProbeFinished(matches);
    }
    private void rememberProbe(String status,String reason){
        JSONObject item=found.get(address);
        if(item!=null)try{item.put("gatt_status",status).put("probe_error",reason);}catch(JSONException ignored){}
    }
    @Override public void ready(){
        if(!sessionCurrent()||!gattVerified){ble.close();return;}
        clearCompatibilityOffer();hardwareReadOnLink=false;connected=true;
        if(!found.containsKey(address))try{found.put(address,new JSONObject().put("address",address).put("name",deviceName));}catch(JSONException ignored){}
        rememberProbe("verified","");
        if(ownership.operationMatches(address)){
            begin("operation_auth","Authorizing recorder",15000);
            long attempt=operation;
            handler.postDelayed(()->{
                if(sessionCurrent()&&connected&&operation==attempt&&pending.equals("operation_auth"))
                    try{ownership.operationAuthorization();}catch(Exception e){ownership.fail(e.getMessage());}
            },1000);
        }else if(ownership.pendingOperation()){
            readIdentity("identity");
        }else{
            connectionStage="authorizing";
            begin("account_authorization","Connected. Checking device key…",30000);
            long attempt=operation;
            String original=originalForConnection;originalForConnection="";
            handler.postDelayed(()->{
                if(!sessionCurrent()||!connected||operation!=attempt||!pending.equals("account_authorization"))return;
                try{ownership.authorizeDaily(address,deviceName,original);}
                catch(Exception e){ownership.fail(e.getMessage());}
            },1000);
        }
    }
    private void readIdentity(String phase){
        connectionStage="hardware_identity";
        begin(phase,"Reading recorder identity",12000);
        final long attempt=operation;
        for(long delay:new long[]{1000,5000})handler.postDelayed(()->{
            if(!destroyed&&sessionCurrent()&&connected&&operation==attempt&&phase.equals(pending)){
                try{ble.send("APP&MAC");}catch(Exception e){closed(e.getMessage());ble.close();}
            }
        },delay);
        publish();
    }
    private void clearCompatibilityOffer(){
        compatibilityToken="";
        JSONObject row=found.get(address);
        if(row!=null){row.remove("identity_timeout");row.remove("compat_token");row.remove("cached_hardware_id");row.remove("operation_compat");}
    }
    private void offerCompatibility(){
        JSONObject row=found.get(address);
        if(!connected||!gattVerified||!sessionCurrent()){
            ownership.fail(IDENTITY_TIMEOUT);return;
        }
        try{
            compatibilityToken=UUID.randomUUID().toString();
            if(row==null){row=new JSONObject().put("address",address).put("name",deviceName);found.put(address,row);}
            row.put("gatt_status","verified").put("identity_timeout",true).put("compat_token",compatibilityToken).put("operation_compat",ownership.pendingOperation());
            JSONObject cached=store.recorderIdentity(address);
            String known=cached.optString("hardware_id");
            if(!known.isEmpty())row.put("cached_hardware_id",RecorderOwnership.canonical(known));
            connectionStage="identity_confirmation";message=IDENTITY_TIMEOUT;log(message);publish();
        }catch(Exception e){clearCompatibilityOffer();ownership.fail(e.getMessage());}
    }
    private void reconnectOwnership(){
        if(!sessionCurrent())return;
        ownershipReconnect=false;ble.close();connected=false;authorized=false;recordState=-1;pending="";operation++;
        long epoch=connectionEpoch;
        handler.postDelayed(()->{if(!sessionCurrent()||epoch!=connectionEpoch)return;try{begin("connect","Reconnecting to verify authorization",27000);ble.connect(adapter.getRemoteDevice(address));}catch(Exception e){problem(e.getMessage());}},700);
    }
    private void nextOwnershipDirectory()throws Exception{
        if(!ownershipInventory)return;
        if(recordState!=0){ownershipInventory=false;throw new IOException("Stop recording before changing recorder ownership.");}
        if(inventoryDirectory<dirs.size()){directory=dirs.get(inventoryDirectory++);files.clear();begin("files","Verifying card files",20000);ble.send("APP&LIST&"+directory);}
        else{ownershipInventory=false;ownershipReading=true;nextOwnershipFile();}
    }
    private void nextOwnershipFile()throws Exception{
        if(!sessionCurrent()||recordState!=0)throw new IOException("Stop recording before changing recorder ownership.");
        if(inventoryFiles.isEmpty()){ownershipReading=false;ownership.inventory(inventoryEntries);return;}
        JSONObject file=inventoryFiles.removeFirst();downloadFile(file.getString("dir"),file.getString("name"),file.getLong("seconds"));
    }
    @Override public void closed(String reason){
        originalForConnection="";clearCompatibilityOffer();
        if(pending.equals("probe"))rememberProbe("failed",reason);
        if(ownershipReconnect&&sessionCurrent()){ownershipReconnect=false;reconnectOwnership();return;}
        ownershipInventory=false;ownershipReading=false;ownership.disconnected();
        releaseRecordingWake();
        abortTransfer();syncFailed(reason);connected=false;authorized=false;recordState=-1;pending="";operation++;if(autoProbing){autoProbing=false;nextAutomaticProbe();return;}message=(pairingRequested?"Android requested a PIN. Cancel the prompt and export diagnostics. ":"")+reason;log(reason);publish();
    }
    private void begin(String kind,String text,long timeout){
        pending=kind;message=text;long generation=++operation;
        handler.postDelayed(()->{
            if(generation!=operation||pending.isEmpty()||destroyed)return;
            if(pending.equals("download")){transferFailed("Transfer did not start in time. Reconnect and try again.");return;}
            String old=pending;pending="";message="Recorder did not confirm the action ("+old+"). Refresh device status or reconnect.";
            if(old.equals("register_identity")){
                connectionStage="gatt_ready";message=REGISTRATION_UNAVAILABLE;log(message);publish();return;
            }
            if(old.equals("identity")){offerCompatibility();return;}
            if(old.equals("auth")&&ownership.authorizingDaily())message="Recorder authorization timed out. Check the original key.";
            if(old.equals("account_authorization")){ownership.fail("Recorder authorization timed out. Check the original key.");return;}
            if(old.equals("verified_identity")){ownership.fail("The recorder did not return its hardware ID after authorization.");return;}
            if(old.equals("probe"))rememberProbe("failed",message);
            if(ownership.changing()){ownershipInventory=false;ownershipReading=false;ownershipReconnect=false;ownership.fail(message);return;}
            if(syncing)syncFailed(message);
            if(old.equals("auth")||old.equals("identity")||old.equals("rotate")||old.equals("start")||old.equals("stop")||old.equals("probe")||old.equals("connect")){ownershipReconnect=false;releaseRecordingWake();ble.close();authorized=false;connected=false;recordState=-1;}
            log(message);publish();if(old.equals("probe"))automaticProbeFinished(false);
        },timeout);
    }
    private void done(String kind){if(pending.equals(kind)){pending="";operation++;}}
    private void refresh()throws Exception{
        dirs.clear();files.clear();directory="";begin("dirs","Loading device status and folders",25000);
        ble.send("APP&FW");ble.send("APP&BAT");ble.send("APP&SPACE");ble.send("APP&RT");ble.send("APP&LIST_DIRS");
    }
    @Override public void command(byte[] data){
        if(!sessionCurrent())return;
        try{for(String value:JwdProtocol.replies(data))if(!value.isEmpty())reply(value.trim());}
        catch(Exception e){if(receiver!=null||pending.equals("download"))transferFailed("Invalid device response: "+e.getMessage());else if(ownership.changing()){ownershipInventory=false;ownershipReading=false;ownership.fail(e.getMessage());}else{syncFailed(e.getMessage());problem("Invalid device response: "+e.getMessage());}}
    }
    private void reply(String value)throws Exception{
        String[] p=value.split("&",-1);if(p.length<2)return;String type=p[1];
        if(type.equals("MAC")&&(pending.equals("identity")||pending.equals("register_identity")||pending.equals("verified_identity")||!compatibilityToken.isEmpty())){
            if(p.length!=3&&!(p.length==4&&p[3].isEmpty()))return;
            String actual;
            try{actual=RecorderOwnership.canonical(p[2]);}catch(IOException invalid){return;}
            hardwareReadOnLink=true;
            boolean afterAuthorization=pending.equals("verified_identity"),registration=pending.equals("register_identity");
            clearCompatibilityOffer();done(pending);
            if(afterAuthorization)ownership.confirmIdentity(actual);
            else ownership.identity(actual,address,deviceName,registration||manualVerifiedSelection);
            publish();return;
        }
        if(type.equals("SK")){
            if(!sessionCurrent())return;
            if(p.length<3)return;
            if(p[2].equals("OK")&&pending.equals("auth")){
                done("auth");if(found.containsKey(address))found.get(address).put("key_rejected",false);ownership.accepted();
            }else if(p[2].equals("ERR")&&pending.equals("auth")){done("auth");if(found.containsKey(address))found.get(address).put("key_rejected",ownership.authorizingDaily());abortTransfer();ble.close();connected=false;authorized=false;ownership.rejected();}
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
                if(recordState==1){recordState=2;recordPausedAt=SystemClock.elapsedRealtime();}
                done("pause");message="Recording paused";break;
            case "RESUME":
                if(recordState==2){recordPausedTotal+=SystemClock.elapsedRealtime()-recordPausedAt;recordPausedAt=0;recordState=1;}
                done("resume");message="Recorder is recording";break;
            case "STO":stopped();done("stop");message="Saved on recorder · Syncing to this phone";log("Recording stop confirmed");scheduleSync();break;
            case "AUTO":if(p.length>2&&p[2].equals("STO")){stopped();scheduleSync();}else if(p.length>3&&p[2].equals("STA"))recording(p[3],0);break;
            case "DISK":case "REC":if(value.endsWith("&ERR")){pending="";operation++;recordState=-1;problem(type.equals("DISK")?"Recorder storage is full":"The recorder reported an audio error");}break;
            case "DIRS":if(pending.equals("dirs")&&p.length>2){String dir=JwdProtocol.part(p[2]);if(!dirs.contains(dir))dirs.add(dir);}break;
            case "DIRS_SUM":if(pending.equals("dirs")&&p.length>2){int total=Integer.parseInt(p[2]);done("dirs");if(total!=dirs.size()){dirs.clear();throw new IOException("Folder list is incomplete. Refresh it.");}Collections.sort(dirs,Collections.reverseOrder());message="Recorder connected · "+dirs.size()+" folders";if(ownershipInventory)nextOwnershipDirectory();else if(syncing)nextSyncDirectory();else if(!deferSync)scheduleSync();}break;
            case "F":if(pending.equals("files")&&p.length>=5&&directory.equals(p[2])){String name=JwdProtocol.part(p[3]);boolean exists=false;for(JSONObject file:files)if(file.optString("name").equals(name))exists=true;if(!exists)files.add(new JSONObject().put("name",name).put("seconds",Long.parseLong(p[4])));}break;
            case "LIST":if(pending.equals("files")&&p.length>2){int total=Integer.parseInt(p[2]);done("files");if(total!=files.size()){files.clear();throw new IOException("File list is incomplete. Load it again.");}Collections.sort(files,(a,b)->b.optString("name").compareTo(a.optString("name")));message="Loaded "+files.size()+" recordings";if(ownershipInventory){for(JSONObject file:files)inventoryFiles.add(new JSONObject(file.toString()).put("dir",directory));nextOwnershipDirectory();}else if(syncing){for(JSONObject file:files)if(!store.deviceRecordSynced(address,directory,file.optString("name"),file.optLong("seconds")))syncFiles.add(new JSONObject(file.toString()).put("dir",directory));nextSyncDirectory();}}break;
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
        recordState=1;recordName=name;recordStart=SystemClock.elapsedRealtime()-Math.max(0,seconds)*1000;recordPausedAt=0;recordPausedTotal=0;
    }
    private void stopped(){
        boolean wasRecording=recordState==1||recordState==2;
        if(!recordName.isEmpty()){syncTarget=recordName;store.pendingDeviceRecord(address,recordName);}
        releaseRecordingWake();recordState=0;recordName="";
        if(wasRecording)scheduleSync();
    }
    private void resetSync(){syncing=false;syncFiles.clear();syncDirectory=0;syncRetry=0;syncError="";}
    private void syncFailed(String error){syncing=false;syncFiles.clear();syncError=error==null?"Reconnect to sync the recording.":error;}
    private void scheduleSync(){
        handler.removeCallbacks(syncLater);handler.postDelayed(syncLater,1500);
    }
    private final Runnable syncLater=()->{if(authorized&&recordState==0&&!deferSync&&!syncing&&pending.isEmpty()&&receiver==null&&!converting)try{startSync();}catch(Exception e){syncFailed(e.getMessage());problem(e.getMessage());}};
    private void startSync()throws Exception{
        if(!sessionCurrent()||ownership.blocked())return;
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
    private void releaseRecordingWake(){if(receiver==null&&!converting)releaseWake();}
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
        if(receiver==null||!sessionCurrent()||!authorized)return; // Live packets are ignored; only complete file transfers are accepted.
        try{receiver.write(data);lastData=SystemClock.elapsedRealtime();maybeFinish();if(lastData-lastPublish>400)publish();}catch(Exception e){transferFailed(e.getMessage());}
    }
    private final Runnable transferWatch=new Runnable(){public void run(){
        if(receiver==null)return;
        if(SystemClock.elapsedRealtime()-lastData>(endSeen?5000:30000)){transferFailed("File transfer timed out or is incomplete. No uploadable file was created.");return;}
        handler.postDelayed(this,1000);
    }};
    private void maybeFinish()throws Exception{
        if(receiver==null||!receiver.complete())return;
        String verification=receiver.finish();receiver=null;handler.removeCallbacks(transferWatch);converting=true;pending="";
        String identity=downloadScope,mac=address,dir=downloadDir,name=downloadName,knownHardware=ownership.syncIdentity();long seconds=downloadSeconds;File source=raw;raw=null;
        message="File received. Verifying and decoding audio…";log(verification.equals("crc32_verified")?"Checksum verified":"Checksum unavailable. File length verified.");publish();
        decoder.execute(()->{
            try{
                if(!identity.equals(store.scope()))throw new IOException("The account changed. The original file was kept without adding it to another account.");
                String digest=JwdAudio.fileHash(source);
                if(ownershipReading){
                    source.delete();handler.post(()->{converting=false;releaseWake();try{inventoryEntries.add(dir+"/"+name+"|"+seconds+"|"+digest);nextOwnershipFile();}catch(Exception e){ownership.fail(e.getMessage());}});return;
                }
                JSONObject draft=JwdAudio.importVerified(store,source,mac,dir,name,seconds,verification,percent->handler.post(()->{if(!destroyed){message="Decoding audio "+percent+"%";publish();}}));
                if(!knownHardware.isEmpty()&&draft.optInt("upload_attempts")==0&&draft.optString("recording_id").isEmpty()&&draft.optString("upload_client_id").isEmpty()){
                    draft.put("upload_client_id","jwd-"+JwdAudio.hash((knownHardware+"\n"+dir+"\n"+name+"\n"+digest).getBytes(StandardCharsets.UTF_8)));
                }
                draft.put("template_id",store.recorderTemplate("jwd:"+mac+"|"+name));store.generationOptions(draft,store.recorderOptions("jwd:"+mac+"|"+name));store.save(draft);
                String notes=store.recorderNotes(mac,name);if(!notes.isEmpty()){draft.put("notes",notes);store.save(draft);}
                store.deviceRecordSynced(mac,dir,name,seconds,draft.optString("id"));
                try{UploadQueue.saved(this,draft);}catch(Exception ignored){/* The verified local draft remains available for manual retry. */}
                source.delete();handler.post(()->{converting=false;releaseWake();if(syncTarget.isEmpty()&&lastDraft.isEmpty()||matchesTarget(name)){lastDraft=draft.optString("id");syncTarget="";store.pendingDeviceRecord(mac,"");}message="Saved on this phone"+(verification.equals("length_only")?" · Device checksum unavailable":" · Checksum verified");log(message);publish();if(syncing)try{nextSyncFile();}catch(Exception e){syncFailed(e.getMessage());problem(e.getMessage());}});
            }catch(Exception e){handler.post(()->{converting=false;releaseWake();syncFailed(e.getMessage());if(ownership.changing()){ownershipInventory=false;ownershipReading=false;ownership.fail(e.getMessage());}else problem("Audio could not finish syncing: "+e.getMessage()+". Original audio is kept.");});}
        });
    }
    private void transferFailed(String reason){abortTransfer();syncFailed(reason);ble.close();authorized=false;connected=false;recordState=-1;pending="";operation++;if(ownership.changing()){ownershipInventory=false;ownershipReading=false;ownership.fail(reason);}else problem(reason);}
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
            s.put("ownership",ownership.view()).put("syncing",syncing).put("sync_target",syncTarget).put("sync_error",syncError).put("busy",syncing||converting||receiver!=null||!pending.isEmpty()||ownership.changing()&&compatibilityToken.isEmpty());
            long now=SystemClock.elapsedRealtime();
            long elapsed=recordState>0?Math.max(0,(recordState==2?recordPausedAt:now)-recordStart-recordPausedTotal)
                :recordName.isEmpty()?0:elapsed(new JSONObject(snapshot),now);
            s.put("elapsed_ms",elapsed).put("elapsed_at",now);
            snapshot=s.toString();if(now-lastPublish>500){((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).notify(13,notification(message));}lastPublish=now;
        }catch(Exception ignored){}
    }
    private JSONArray verifiedDevices(){
        return new JSONArray(found.values());
    }
    @Override public void onDestroy(){
        try{unregisterReceiver(pairingReceiver);}catch(IllegalArgumentException ignored){}
        active=false;handler.post(()->{releaseRecordingWake();stopScan();abortTransfer();ble.close();connected=false;authorized=false;recordState=-1;pending="";operation++;publish();destroyed=true;releaseWake();thread.quitSafely();});
        ownership.dispose();decoder.shutdownNow();super.onDestroy();
    }
}
