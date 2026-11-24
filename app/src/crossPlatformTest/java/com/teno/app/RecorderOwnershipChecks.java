package com.teno.app;

import android.bluetooth.BluetoothDevice;
import android.content.*;
import android.os.Handler;
import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import java.util.zip.CRC32;

/** Actual release service/API/Keystore with isolated HTTP and synthetic BLE, never a real card. */
final class RecorderOwnershipChecks implements AutoCloseable {
    final RuntimeInstrumentation test;final Context context;final Store store;
    final ServerSocket server;final ExecutorService http=Executors.newSingleThreadExecutor();
    final String mac="A0B1C2D3E4F5",address="A0:B1:C2:D3:E4:F0",oldKey="OriginalCode1234",newKey="Transferred12345";
    final List<String> commands=new CopyOnWriteArrayList<>();final List<String> checkpoints=new CopyOnWriteArrayList<>();
    volatile String bound=oldKey,op="claim-fixture",state="prepared",stage="",before="",claimKey="";
    volatile boolean owned,completeLoss,reportIdentity;volatile int rejected,completes,downloads;
    byte[] audio;JwdService service;Handler handler;String snapshot;
    interface Work{void run()throws Exception;}
    RecorderOwnershipChecks(RuntimeInstrumentation test)throws Exception{
        this.test=test;context=test.getTargetContext();store=new Store(context);server=new ServerSocket(0,10,InetAddress.getByName("127.0.0.1"));
        http.execute(()->{while(!server.isClosed())try(Socket socket=server.accept()){
            socket.setSoTimeout(10000);InputStream input=socket.getInputStream();ByteArrayOutputStream head=new ByteArrayOutputStream();int b;
            while((b=input.read())>=0){head.write(b);byte[] bytes=head.toByteArray();int n=bytes.length;if(n>=4&&bytes[n-4]==13&&bytes[n-3]==10&&bytes[n-2]==13&&bytes[n-1]==10)break;}
            String headers=head.toString("UTF-8"),path=headers.split(" ")[1];int length=0;
            for(String line:headers.split("\r\n"))if(line.toLowerCase(Locale.ROOT).startsWith("content-length:"))length=Integer.parseInt(line.substring(15).trim());
            String data=new String(input.readNBytes(length),StandardCharsets.UTF_8);JSONObject body=data.isEmpty()?new JSONObject():new JSONObject(data);
            JSONObject result=respond(path,body);boolean error=result.optBoolean("fixture_error");byte[] bytes=result.toString().getBytes(StandardCharsets.UTF_8);
            OutputStream output=socket.getOutputStream();output.write(((error?"HTTP/1.1 503 Service Unavailable":"HTTP/1.1 200 OK")+"\r\nContent-Type: application/json\r\nContent-Length: "+bytes.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));output.write(bytes);output.flush();
        }catch(Exception e){if(!server.isClosed())throw new RuntimeException(e);}});
    }
    JSONObject recorder()throws Exception{return new JSONObject().put("id","recorder-fixture").put("hardware_id",mac).put("name","Synthetic recorder").put("epoch",owned?1:2);}
    JSONObject operation()throws Exception{return new JSONObject().put("id",op).put("kind",op.startsWith("claim")?"claim":"release").put("state",state).put("recorder",recorder()).put("checkpoint",new JSONObject().put("stage",stage).put("files_before",before));}
    JSONObject respond(String path,JSONObject body)throws Exception{
        if(path.endsWith("/connection-key"))return new JSONObject().put("device_key",body.optString("original_key","AccountCode12345"));
        if(path.endsWith("/resolve"))return new JSONObject().put("state",owned?"owned":"claim_required").put("recorder",recorder());
        if(path.endsWith("/claim")){
            test.check(body.optBoolean("confirm_card_recordings")&&body.optString("original_key").equals(oldKey),"optional_registration_preserves_key_accepted_by_card");
            claimKey=oldKey;op="claim-fixture";state="prepared";return operation();
        }
        if(path.endsWith("/restore"))return recorder().put("device_key",oldKey);
        if(path.endsWith("/claim-rejected")){state="cancelled";return operation();}
        if(path.endsWith("/start")){if(!state.equals("completed"))state="hardware_pending";return operation().put("device_key",op.startsWith("claim")?claimKey:newKey).put("previous_key",oldKey);}
        if(path.endsWith("/checkpoint")){stage=body.getString("stage");before=body.getString("files_before");checkpoints.add(stage);return operation();}
        if(path.endsWith("/complete")){
            completes++;state="completed";owned=op.startsWith("claim");
            if(!owned)test.check(body.optBoolean("old_key_rejected")&&body.optString("files_before").equals(body.optString("files_after"))&&downloads>=3,"transfer_checks_full_files_before_and_after_and_old_key_rejection");
            if(completeLoss){completeLoss=false;return new JSONObject().put("fixture_error",true).put("code","FIXTURE_REPLY_LOST").put("message","Synthetic reply unavailable");}return operation();
        }
        throw new IOException("Unexpected fixture route "+path);
    }
    void onService(Work work)throws Exception{CountDownLatch done=new CountDownLatch(1);AtomicReference<Throwable> error=new AtomicReference<>();handler.post(()->{try{work.run();}catch(Throwable e){error.set(e);}finally{done.countDown();}});if(!done.await(5,TimeUnit.SECONDS))throw new IOException("Handler timeout");if(error.get()!=null)throw new IOException(error.get());}
    void reply(String value){service.command(value.getBytes(StandardCharsets.US_ASCII));}
    void ble(String command){commands.add(command);handler.postDelayed(()->{try{
        if(command.equals("APP&MAC")){if(reportIdentity)reply("MCU&MAC&"+mac);}
        else if(command.startsWith("APP&SK&")){String key=command.substring(7);if(bound.isEmpty())bound=key;if(bound.equals(key))reply("MCU&SK&OK");else{rejected++;reply("MCU&SK&ERR");}}
        else if(command.equals("APP&BLE&OFF")){bound="";service.closed("Synthetic unbind disconnect");}
        else if(command.equals("APP&RT"))reply("MCU&RT&0");
        else if(command.equals("APP&LIST_DIRS")){reply("MCU&DIRS&fixture");reply("MCU&DIRS_SUM&1");}
        else if(command.startsWith("APP&LIST&")){reply("MCU&F&fixture&sample.wav&2");reply("MCU&LIST&1");}
        else if(command.startsWith("APP&U&")){downloads++;reply("MCU&U&"+audio.length);service.audio(audio);CRC32 crc=new CRC32();crc.update(audio);reply("MCU&OFF&"+String.format(Locale.ROOT,"%08X",crc.getValue()));}
    }catch(Exception e){throw new RuntimeException(e);}},15);}
    void action(String name,JSONObject args)throws Exception{onService(()->{
        java.lang.reflect.Method method=JwdService.class.getDeclaredMethod("handle",Intent.class);method.setAccessible(true);
        method.invoke(service,new Intent().setAction(name).putExtra("operation_id",args.optString("operation_id")).putExtra("original_key",args.optString("original_key")).putExtra("confirm",args.optBoolean("confirm")));
    });}
    void run()throws Exception{
        SharedPreferences prefs=context.getSharedPreferences("teno",0);if(!store.scope().isEmpty()&&!prefs.getBoolean("runtime_test_fixture",false))throw new IOException("Dedicated fixture required");
        Map<String,String> saved=new HashMap<>();for(String key:Arrays.asList("scope","username","session","server"))saved.put(key,prefs.getString(key,null));snapshot=JwdService.snapshot;
        try{
            store.base("http://127.0.0.1:"+server.getLocalPort());store.identity("Ownership fixture","ownership-"+System.nanoTime());store.tokens(new JSONObject().put("access_token","synthetic-ownership-fixture"));store.recordingOptions(false,false,false);store.deviceKey(address,oldKey);
            String originalScope=store.scope();store.identity("Other fixture","different-ownership");test.check(store.deviceKey(address).isEmpty(),"device_key_is_inaccessible_after_account_switch");prefs.edit().putString("scope",originalScope).commit();
            ByteArrayOutputStream bytes=new ByteArrayOutputStream();bytes.write(JwdAudio.wavHeader(64000));bytes.write(new byte[64000]);audio=bytes.toByteArray();
            service=new JwdService();java.lang.reflect.Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(service,context);test.runOnMainSync(service::onCreate);handler=(Handler)JwdAutomaticChecks.get(service,"handler");
            onService(()->{
                JwdAutomaticChecks.set(service,"ble",new JwdTransport(){public void connect(BluetoothDevice device){handler.post(()->{service.stage("jwd_service_verified");service.ready();});}public void probe(BluetoothDevice device){}public void close(){}public void send(String value){ble(value);}});
                JwdAutomaticChecks.set(service,"address",address);JwdAutomaticChecks.set(service,"deviceName","Synthetic recorder");JwdAutomaticChecks.set(service,"connectionOwner",store.scope());JwdAutomaticChecks.set(service,"connectionEpoch",JwdService.sessionEpoch.get());JwdService.accountClosing=false;service.stage("jwd_service_verified");service.ready();
            });
            test.until(()->new JSONObject(JwdService.snapshot).optBoolean("authorized")&&store.drafts().length()>0&&!new JSONObject(JwdService.snapshot).optBoolean("busy"));
            test.check(commands.get(0).equals("APP&SK&"+oldKey)&&!commands.contains("APP&MAC"),"daily_connection_saves_audio_without_a_hardware_id");
            test.check(commands.contains("APP&LIST_DIRS")&&downloads==1&&store.recorderIdentity(address).optString("hardware_id").isEmpty(),"files_sync_after_key_ack_without_cloud_registration");
            JSONObject local=store.drafts().getJSONObject(0);
            action("ownership_register",new JSONObject());
            test.until(()->new JSONObject(JwdService.snapshot).optString("message").equals(JwdService.REGISTRATION_UNAVAILABLE));
            test.check(new JSONObject(JwdService.snapshot).optBoolean("authorized")&&new JSONObject(JwdService.snapshot).getJSONObject("ownership").optString("state").equals("authorized"),"optional_registration_timeout_keeps_normal_connection");
            reportIdentity=true;action("ownership_register",new JSONObject());
            test.until(()->new JSONObject(JwdService.snapshot).getJSONObject("ownership").optBoolean("claim_required"));
            action("ownership_claim",new JSONObject().put("confirm",true));
            test.until(()->owned&&new JSONObject(JwdService.snapshot).optBoolean("authorized")&&!new JSONObject(JwdService.snapshot).optBoolean("busy"));
            test.check(store.deviceKey(address).equals(oldKey)&&store.recorderIdentity(address).optString("hardware_id").equals(mac),"only_explicit_registration_saves_verified_identity");
            test.check(!local.optBoolean("upload_requested"),"ownership_registration_keeps_explicit_cloud_off");
            op="release-fixture";state="ready";stage="";before="";completeLoss=true;
            action("ownership_operation",new JSONObject().put("operation_id",op));
            test.until(()->state.equals("completed")&&!owned&&completes==2);
            test.until(()->new JSONObject(JwdService.snapshot).getJSONObject("ownership").optString("state").equals("recovery_required"));
            test.check(bound.equals(newKey)&&rejected==1&&checkpoints.contains("old_key_rejected"),"new_key_is_accepted_and_old_key_is_explicitly_rejected");
            test.check(commands.stream().noneMatch(s->s.contains("RESET")||s.equals("APP&STA")),"transfer_never_formats_or_starts_recording");
            action("ownership_operation",new JSONObject().put("operation_id",op));
            test.until(()->new JSONObject(JwdService.snapshot).getJSONObject("ownership").optString("state").equals("completed"));
            test.check(store.deviceKey(address).isEmpty()&&store.drafts().length()==1,"lost_receipt_recovery_revokes_old_local_key_without_moving_or_deleting_recordings");
            test.check(completes==2,"retry_after_server_commit_does_not_repeat_hardware_change");
        }finally{
            JSONObject diagnostics=new JSONObject().put("snapshot",new JSONObject(JwdService.snapshot)).put("commands",new JSONArray(commands.stream().map(s->s.startsWith("APP&SK&")?"APP&SK&[redacted]":s).toArray())).put("stage",stage).put("downloads",downloads);
            java.nio.file.Files.write(new File(context.getExternalFilesDir(null),"ownership-090-diagnostics.json").toPath(),diagnostics.toString(2).getBytes(StandardCharsets.UTF_8));
            if(service!=null){test.runOnMainSync(service::onDestroy);((Thread)JwdAutomaticChecks.get(service,"thread")).join(3000);}JwdService.accountClosing=false;JwdService.snapshot=snapshot;
            SharedPreferences.Editor edit=prefs.edit();for(Map.Entry<String,String> item:saved.entrySet()){if(item.getValue()==null)edit.remove(item.getKey());else edit.putString(item.getKey(),item.getValue());}edit.commit();
        }
    }
    public void close()throws Exception{server.close();http.shutdownNow();}
}
