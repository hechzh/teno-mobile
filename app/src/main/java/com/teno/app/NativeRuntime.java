package com.teno.app;

import android.Manifest;
import android.content.Intent;
import android.os.*;
import io.flutter.plugin.common.BinaryMessenger;
import org.json.*;
import java.io.*;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.*;
import java.util.concurrent.*;
import static com.teno.app.RuntimeMessages.*;

/** Native services own recording, files, keys and upload work; Flutter owns presentation. */
final class NativeRuntime implements RuntimeHost {
    final MainActivity activity;
    final Store store;
    final Api api;
    final Handler main=new Handler(Looper.getMainLooper());
    final ExecutorService io=Executors.newSingleThreadExecutor();
    final NativeMedia media;
    private final BinaryMessenger messenger;
    private final RuntimeEvents events;
    private boolean closed,visible;
    private volatile boolean phoneStarting;
    private long sequence;
    private String route="",lastSource="phone";
    NativeRuntime(MainActivity activity,BinaryMessenger messenger){
        this.activity=activity;this.messenger=messenger;store=new Store(activity);api=new Api(store);
        media=new NativeMedia(this);events=new RuntimeEvents(messenger);RuntimeHost.setUp(messenger,this);
    }
    interface Work<T>{T run()throws Exception;}
    interface Action{void run()throws Exception;}
    FlutterError failure(Throwable e){
        String code=e instanceof Api.Failure?((Api.Failure)e).code:e instanceof SecurityException?"PERMISSION_REQUIRED":"ACTION_FAILED";
        return new FlutterError(code,e.getMessage()==null?"The action could not be completed. Try again.":e.getMessage(),null);
    }
    <T> void work(Result<T> result,Work<T> action){
        io.execute(()->{try{T value=action.run();main.post(()->{if(!closed)result.success(value);});}
            catch(Exception e){main.post(()->{if(!closed)result.error(failure(e));});}});
    }
    void work(VoidResult result,Action action){
        work(new Result<Boolean>(){public void success(Boolean value){result.success();}public void error(Throwable e){result.error(e);}},
            ()->{action.run();return true;});
    }
    void ui(VoidResult result,Action action){main.post(()->{try{action.run();result.success();}catch(Exception e){result.error(failure(e));}});}
    void resume(){visible=true;main.removeCallbacks(tick);main.post(tick);}
    void suspendUi(){visible=false;main.removeCallbacks(tick);}
    private final Runnable tick=new Runnable(){public void run(){
        if(closed||!visible)return;
        try{events.changed(state(),new VoidResult(){public void success(){}public void error(Throwable e){}});}
        catch(Exception ignored){/* Explicit snapshots can retry; never log private state. */}
        main.postDelayed(this,500);
    }};
    void acceptIntent(Intent intent){
        if(intent==null)return;
        if(intent.hasExtra("recording_id")){route="recording:"+intent.getStringExtra("recording_id");intent.removeExtra("recording_id");}
        else if(intent.hasExtra("open_recording")){route="capture:"+SystemClock.elapsedRealtime();intent.removeExtra("open_recording");}
        else if(intent.hasExtra("open_device")){route="device:"+SystemClock.elapsedRealtime();intent.removeExtra("open_device");}
    }
    private SessionState session(){
        return new SessionState.Builder().setSignedIn(!store.scope().isEmpty()&&!store.token("access_token").isEmpty())
            .setUsername(store.name()).setScope(store.scope()).setServer(store.base()).setCloudUpload(store.autoUpload())
            .setWifiOnly(store.wifiUpload()).setLivePreview(store.liveDefault()).setOptionsSet(store.recordingOptionsSet()).build();
    }
    JSONObject device()throws JSONException{return new JSONObject(JwdService.snapshot);}
    private boolean hardwareCapturing()throws Exception{
        JSONObject d=device();return d.optInt("record_state",-1)>0
            ||d.optInt("record_state",-1)<0&&!d.optString("record_name").isEmpty()
            ||Arrays.asList("start","stop","pause","resume").contains(d.optString("pending"));
    }
    private void accountIdle()throws Exception{
        JSONObject d=device();
        if(phoneStarting||RecorderService.active||RecorderService.finishing||hardwareCapturing()||UploadQueue.running.get()
            ||d.optBoolean("receiving")||d.optBoolean("converting")||d.optBoolean("syncing"))
            throw new IOException("Finish recording and transfers before changing accounts.");
    }
    void signedIn()throws IOException{if(store.scope().isEmpty()||store.token("access_token").isEmpty())throw new IOException("Sign in to your Teno account first.");}
    JSONObject local(String id)throws Exception{
        if(!id.matches("[A-Za-z0-9_-]{1,128}"))throw new IOException("Invalid local recording.");
        JSONObject d=store.draft(id);if(!store.scope().equals(d.optString("scope")))throw new IOException("Sign in to this recording's account.");
        return d;
    }
    RuntimeState state()throws Exception{
        JSONObject d=device();JSONArray candidates=d.optJSONArray("devices");if(candidates==null)candidates=new JSONArray();
        for(int i=0;i<candidates.length();i++){JSONObject item=candidates.getJSONObject(i);item.put("has_key",!store.deviceKey(item.optString("address")).isEmpty());}
        String phase="idle",source="phone",id=RecorderService.draftId,status=RecorderService.error,notes="",partial="",segments="[]";
        long elapsed=RecorderService.elapsed();LiveTranscriber live=RecorderService.live;
        if(RecorderService.active){phoneStarting=false;phase=RecorderService.paused?"paused":"recording";}
        else if(RecorderService.finishing)phase="saving";
        else if(phoneStarting&&RecorderService.error.isEmpty())phase="starting";
        else phoneStarting=false;
        if(!id.isEmpty())try{JSONObject draft=local(id);notes=draft.optString("notes");if(phase.equals("idle")&&status.isEmpty())status="Saved on this phone";}catch(Exception ignored){}
        if(hardwareCapturing()||d.optBoolean("receiving")||d.optBoolean("converting")||d.optBoolean("syncing")){
            source="device";lastSource="device";int rs=d.optInt("record_state",-1);String pending=d.optString("pending");
            phase=rs==2?"paused":rs==1?"recording":rs<0&&!d.optString("record_name").isEmpty()?"interrupted":"idle";
            if(pending.equals("start"))phase="starting";else if(pending.equals("stop"))phase="stopping";
            else if(d.optBoolean("receiving")||d.optBoolean("converting")||d.optBoolean("syncing"))phase="saving";
            elapsed=d.optLong("elapsed_ms");id="jwd:"+d.optString("address")+"|"+d.optString("record_name");
            notes=store.recorderNotes(d.optString("address"),d.optString("record_name"));status=d.optString("message");
            live=JwdService.live==null?null:JwdService.live.transcriber;
        }else if(lastSource.equals("device")&&!d.optString("last_draft").isEmpty()&&!RecorderService.active&&!RecorderService.finishing&&!phoneStarting){
            source="device";id=d.optString("last_draft");
            try{JSONObject draft=local(id);notes=draft.optString("notes");elapsed=draft.optLong("duration_ms");}catch(Exception ignored){}
            status=d.optString("message");live=JwdService.live==null?null:JwdService.live.transcriber;
        }
        if(live!=null){partial=live.partial;segments=live.segments().toString();if(status.isEmpty())status=live.status;}
        if(status.isEmpty())status=phase.equals("paused")?"Recording paused":phase.equals("recording")?"Recording · Audio saved locally":"Ready";
        JSONArray drafts=session().getSignedIn()?store.drafts():new JSONArray();
        for(int i=0;i<drafts.length();i++)drafts.getJSONObject(i).remove("path");
        return new RuntimeState.Builder().setSequence(++sequence).setSession(session())
            .setCapture(new CaptureState.Builder().setSource(source).setPhase(phase).setElapsedMs(elapsed).setLocalId(id)
                .setStatus(status).setPartial(partial).setSegmentsJson(segments).setNotes(notes).build())
            .setDevice(new DeviceState.Builder().setConnected(d.optBoolean("connected")).setAuthorized(d.optBoolean("authorized"))
                .setScanning(d.optBoolean("scanning")).setBusy(d.optBoolean("busy")).setReceiving(d.optBoolean("receiving"))
                .setReceivedBytes(d.optLong("received")).setExpectedBytes(d.optLong("expected")).setIdentifier(d.optString("address").isEmpty()?store.recorderAddress():d.optString("address"))
                .setName(d.optString("name",store.recorderName())).setBattery(d.optString("battery","Not received"))
                .setStatus(d.optString("message","Connect your recorder to get started.")).setCandidatesJson(candidates.toString())
                .setFilesJson(d.optJSONArray("files")==null?"[]":d.getJSONArray("files").toString()).build())
            .setPlayback(media.state()).setDraftsJson(drafts.toString()).setUploadStatus(TransferService.message==null?"":TransferService.message).setOpenRoute(route).build();
    }
    @Override public void snapshot(Result<RuntimeState> result){try{result.success(state());}catch(Exception e){result.error(failure(e));}}
    @Override public void login(String server,String username,String password,Result<SessionState> result){
        work(result,()->{accountIdle();if(!store.token("access_token").isEmpty())throw new IOException("Sign out before changing accounts.");
            store.base(Api.validateBase(server));try{api.login(username,password);api.ensureNativePreferences();}catch(Exception e){store.logout();throw e;}
            UploadQueue.resume(activity);return session();});
    }
    @Override public void logout(VoidResult result){
        work(result,()->{accountIdle();try{api.post("/api/v1/auth/logout",new JSONObject());}catch(IOException ignored){}finally{store.logout();}
            main.post(media::releasePlayer);route="";});
    }
    @Override public void request(String method,String path,String json,Result<String> result){
        work(result,()->{signedIn();URI uri=new URI(path);
            if(uri.isAbsolute()||uri.getAuthority()!=null||!uri.normalize().getPath().startsWith("/api/v1/")
                ||!Arrays.asList("GET","POST","PATCH","DELETE").contains(method))throw new IOException("Unsupported API request.");
            String owner=store.scope();JSONObject body=json==null?null:new JSONObject(json);
            JSONObject answer=path.equals("/api/v1/me")&&method.equals("PATCH")?api.savePreferences(body):api.request(method,path,body);
            if(!owner.equals(store.scope()))throw new IOException("Account changed. Reload this page.");return answer.toString();});
    }
    @Override public void configure(Boolean cloud,Boolean wifi,Boolean live,VoidResult result){
        work(result,()->{signedIn();store.recordingOptions(cloud,wifi,live);UploadQueue.resume(activity);});
    }
    @Override public void startPhone(String title,Result<String> result){
        activity.permissions(new String[]{Manifest.permission.RECORD_AUDIO},()->work(result,()->{
            signedIn();if(phoneStarting||RecorderService.active||RecorderService.finishing||hardwareCapturing())throw new IOException("Finish the current recording first.");
            JSONObject draft=store.newDraft(title,".wav");draft.put("live",store.liveDefault());store.save(draft);
            String id=draft.getString("id");lastSource="phone";phoneStarting=true;RecorderService.error="";
            main.post(()->{try{activity.startForegroundService(new Intent(activity,RecorderService.class).setAction("start").putExtra("id",id));}
                catch(RuntimeException e){phoneStarting=false;RecorderService.error="Recording could not start. Open the app and try again.";}});
            return id;
        }),e->result.error(failure(e)));
    }
    @Override public void controlPhone(PhoneAction action,VoidResult result){ui(result,()->{
        if(!RecorderService.active&&!RecorderService.finishing)throw new IOException("There is no active phone recording.");
        String command=action==PhoneAction.STOP?"stop":action==PhoneAction.RETRY_PREVIEW?"retry_live":"pause";
        if(action==PhoneAction.PAUSE&&RecorderService.paused||action==PhoneAction.RESUME&&!RecorderService.paused)return;
        activity.startService(new Intent(activity,RecorderService.class).setAction(command));
    });}
    private String[] bluetoothPermissions(){return Build.VERSION.SDK_INT>=31?new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT}:new String[]{Manifest.permission.ACCESS_FINE_LOCATION};}
    void sendDevice(DeviceAction action,String id,String name)throws Exception{
        String command=switch(action){case SCAN->"scan";case COMPATIBILITY_SCAN->"scan_compat";case CANCEL_TRANSFER->"cancel";default->action.name().toLowerCase(Locale.ROOT);};
        if(action==DeviceAction.SYNC)signedIn();
        if(action==DeviceAction.START){signedIn();if(RecorderService.active||RecorderService.finishing||phoneStarting)throw new IOException("Finish the phone recording first.");lastSource="device";}
        if(action==DeviceAction.CONNECT&&id.isEmpty()){id=store.recorderAddress();name=store.recorderName();}
        activity.startForegroundService(new Intent(activity,JwdService.class).setAction(command).putExtra("address",id)
            .putExtra("name",name).putExtra("live",session().getSignedIn()&&store.liveDefault()));
    }
    @Override public void controlDevice(DeviceAction action,String id,String name,VoidResult result){
        activity.permissions(bluetoothPermissions(),()->ui(result,()->sendDevice(action,id,name)),e->result.error(failure(e)));
    }
    @Override public void bindDevice(String id,String name,String key,Boolean createNew,VoidResult result){
        work(new Result<Boolean>(){public void error(Throwable e){result.error(e);}public void success(Boolean value){ui(result,()->sendDevice(DeviceAction.CONNECT,id,name));}},()->{
            boolean verified=false;JSONArray candidates=device().optJSONArray("devices");
            if(candidates!=null)for(int i=0;i<candidates.length();i++){JSONObject d=candidates.getJSONObject(i);if(id.equals(d.optString("address"))&&d.optString("gatt_status").equals("verified"))verified=true;}
            if(!verified)throw new IOException("Check the recorder service before saving a device key.");
            String value=key;if(createNew){
                if(!store.deviceKey(id).isEmpty())throw new IOException("This recorder already has a saved key.");
                String alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";SecureRandom random=new SecureRandom();StringBuilder generated=new StringBuilder();
                for(int i=0;i<16;i++)generated.append(alphabet.charAt(random.nextInt(alphabet.length())));value=generated.toString();
            }
            store.deviceKey(id,value);return true;
        });
    }
    @Override public void showDeviceKey(VoidResult result){media.showDeviceKey(result);}
    @Override public void saveNotes(String id,String notes,VoidResult result){work(result,()->{
        signedIn();if(notes.getBytes(StandardCharsets.UTF_8).length>180000)throw new IOException("Recording notes are too long.");
        if(id.startsWith("jwd:")){
            String[] parts=id.substring(4).split("\\|",2);if(parts.length!=2||parts[1].isEmpty())return;
            store.recorderNotes(parts[0],parts[1],notes);
        }else synchronized(Store.class){JSONObject d=local(id);d.put("notes",notes);store.save(d);}
    });}
    @Override public void retryUpload(String id,VoidResult result){work(result,()->{signedIn();local(id);UploadQueue.enqueue(store,id,false);UploadQueue.resume(activity);});}
    @Override public void deleteLocal(String id,VoidResult result){work(result,()->{
        signedIn();if(UploadQueue.running.get()||id.equals(RecorderService.draftId)&&(RecorderService.active||RecorderService.finishing))throw new IOException("Wait for the active recording or upload to finish.");
        synchronized(Store.class){JSONObject d=local(id);main.post(()->media.releaseIfPlaying(id));store.deleteDraft(d);}
    });}
    @Override public void importAudio(NullableResult<String> result){media.importAudio(result);}
    @Override public void playback(PlaybackAction action,String id,Boolean local,Long position,Double speed,VoidResult result){media.playback(action,id,local,position,speed,result);}
    @Override public void shareExport(String id,String format,VoidResult result){media.shareExport(id,format,result);}
    @Override public void shareText(String text,VoidResult result){ui(result,()->activity.startActivity(Intent.createChooser(
        new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,text),"Share Teno notes")));}
    void close(){closed=true;visible=false;main.removeCallbacks(tick);RuntimeHost.setUp(messenger,null);media.releasePlayer();io.shutdown();}
}
