package com.teno.app;

import android.bluetooth.BluetoothDevice;
import android.content.*;
import android.os.Handler;
import org.json.*;
import java.io.*;
import java.lang.reflect.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import java.util.zip.CRC32;

/** Real release sync/save/queue code, synthetic BLE bytes, no radio or cloud requests. */
final class JwdSyncDefaultsChecks {
    private final RuntimeInstrumentation test;
    private final Context context;
    private final Store store;
    private final List<String> sent=new CopyOnWriteArrayList<>();
    private final String address="00:00:00:00:08:29";
    private JwdService service; private Handler handler;
    private String filename="first-default.wav";
    private byte[] audio;
    private int downloads;
    private interface Work {void run()throws Exception;}
    JwdSyncDefaultsChecks(RuntimeInstrumentation test){this.test=test;context=test.getTargetContext();store=new Store(context);}
    static Object get(Object target,String name)throws Exception{Field f=target.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(target);}
    static void set(Object target,String name,Object value)throws Exception{Field f=target.getClass().getDeclaredField(name);f.setAccessible(true);f.set(target,value);}
    void onService(Work work)throws Exception{
        CountDownLatch done=new CountDownLatch(1);AtomicReference<Throwable> error=new AtomicReference<>();
        handler.post(()->{try{work.run();}catch(Throwable e){error.set(e);}finally{done.countDown();}});
        if(!done.await(5,TimeUnit.SECONDS))throw new IOException("Sync fixture handler timeout");
        if(error.get()!=null)throw new IOException(error.get());
    }
    void reply(String value){service.command(value.getBytes(StandardCharsets.US_ASCII));}
    void action(String action)throws Exception{onService(()->{Method m=JwdService.class.getDeclaredMethod("handle",Intent.class);m.setAccessible(true);m.invoke(service,new Intent().setAction(action));});}
    void respond(String command){
        sent.add(command);
        handler.postDelayed(()->{
            if(command.equals("APP&LIST_DIRS")){reply("MCU&DIRS&fixture");reply("MCU&DIRS_SUM&1");}
            else if(command.startsWith("APP&LIST&")){reply("MCU&F&fixture&"+filename+"&2");reply("MCU&LIST&1");}
            else if(command.startsWith("APP&U&")){
                downloads++;reply("MCU&U&"+audio.length);service.audio(audio);
                CRC32 crc=new CRC32();crc.update(audio);reply("MCU&OFF&"+String.format(Locale.ROOT,"%08X",crc.getValue()));
            }
        },20);
    }
    JSONObject waitSaved(String name)throws Exception{
        test.until(()->{for(int i=0;i<store.drafts().length();i++)if(store.drafts().getJSONObject(i).optString("jwd_file").equals(name))return true;return false;});
        test.until(()->!new JSONObject(JwdService.snapshot).optBoolean("syncing")&&!new JSONObject(JwdService.snapshot).optBoolean("converting"));
        for(int i=0;i<store.drafts().length();i++){JSONObject d=store.drafts().getJSONObject(i);if(d.optString("jwd_file").equals(name))return d;}
        throw new IOException("Missing verified fixture");
    }
    void run()throws Exception{
        SharedPreferences prefs=context.getSharedPreferences("teno",0);
        if(!store.scope().isEmpty()&&!prefs.getBoolean("runtime_test_fixture",false))throw new IOException("Dedicated fixture required");
        Map<String,String> saved=new HashMap<>();for(String key:Arrays.asList("scope","username","session","server"))saved.put(key,prefs.getString(key,null));
        String snapshot=JwdService.snapshot;
        try{
            UploadQueue.pauseAccount(context);
            store.base("http://127.0.0.1:9");store.identity("Automatic sync fixture","sync-defaults-"+System.nanoTime());
            store.tokens(new JSONObject().put("access_token","synthetic-sync-fixture"));
            test.check(!store.recordingOptionsSet()&&store.autoUpload(),"new_account_defaults_to_cloud_without_preferences_confirmation");
            ByteArrayOutputStream bytes=new ByteArrayOutputStream();bytes.write(JwdAudio.wavHeader(64000));bytes.write(new byte[64000]);audio=bytes.toByteArray();
            service=new JwdService();Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(service,context);
            test.runOnMainSync(service::onCreate);handler=(Handler)get(service,"handler");
            onService(()->{
                set(service,"ble",new JwdTransport(){public void connect(BluetoothDevice d){}public void probe(BluetoothDevice d){}public void close(){}public void send(String value){respond(value);}});
                set(service,"address",address);set(service,"deviceName","Synthetic recorder");set(service,"connected",true);set(service,"authorized",true);set(service,"recordState",0);
                set(service,"connectionOwner",store.scope());set(service,"connectionEpoch",JwdService.sessionEpoch.get());JwdService.accountClosing=false;
                reply("MCU&AUTO&STA&"+filename);reply("MCU&AUTO&STO");
            });
            JSONObject first=waitSaved(filename);
            test.check(downloads==1&&sent.contains("APP&LIST_DIRS"),"hardware_stop_auto_syncs_without_opening_settings");
            test.check(first.optBoolean("upload_requested")&&first.optBoolean("upload_automatic"),"verified_first_recording_is_automatically_queued_for_upload");
            test.check(first.optString("jwd_verification").equals("crc32_verified")&&Arrays.equals(Files.readAllBytes(new File(first.getString("path")).toPath()),audio),"complete_audio_and_checksum_are_kept_before_upload");
            test.check(!store.recordingOptionsSet(),"automatic_sync_does_not_fabricate_preference_confirmation");
            action("sync");Thread.sleep(500);test.check(downloads==1&&store.drafts().length()==1,"manual_repeat_does_not_duplicate_saved_file_or_upload");
            filename="manual-default.wav";action("sync");JSONObject manual=waitSaved(filename);
            test.check(manual.optBoolean("upload_requested"),"manual_sync_also_uses_default_auto_upload_without_setup");
            // An explicit cloud opt-out must not prevent recorder-to-phone synchronization.
            prefs.edit().putBoolean("auto_upload."+store.scope(),false).remove("recording_options."+store.scope()).commit();
            filename="cloud-disabled.wav";onService(()->{reply("MCU&AUTO&STA&"+filename);reply("MCU&AUTO&STO");});JSONObject local=waitSaved(filename);
            test.check(!local.optBoolean("upload_requested")&&new File(local.getString("path")).isFile(),"cloud_off_still_saves_recorder_file_on_phone");
            test.check(!store.autoUpload()&&!store.recordingOptionsSet(),"explicit_cloud_off_is_not_changed_by_sync");
            int count=sent.size();JwdService.accountClosing=true;JwdService.sessionEpoch.incrementAndGet();
            onService(()->{Method m=JwdService.class.getDeclaredMethod("startSync");m.setAccessible(true);m.invoke(service);});
            test.check(sent.size()==count,"late_sync_after_logout_cannot_access_the_recorder");
        }finally{
            if(service!=null){test.runOnMainSync(service::onDestroy);((Thread)get(service,"thread")).join(3000);}
            JwdService.accountClosing=false;JwdService.snapshot=snapshot;
            SharedPreferences.Editor edit=prefs.edit();for(Map.Entry<String,String> e:saved.entrySet()){if(e.getValue()==null)edit.remove(e.getKey());else edit.putString(e.getKey(),e.getValue());}edit.commit();
        }
    }
}
