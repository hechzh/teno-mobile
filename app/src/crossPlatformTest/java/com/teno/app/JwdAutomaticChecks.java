package com.teno.app;

import android.bluetooth.*;
import android.content.*;
import android.os.*;
import org.json.*;
import java.lang.reflect.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** Exercises the release service state machine with a synthetic transport; no radio or auth writes. */
final class JwdAutomaticChecks {
    static Object get(Object target,String name)throws Exception{Field f=target.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(target);}
    static void set(Object target,String name,Object value)throws Exception{Field f=target.getClass().getDeclaredField(name);f.setAccessible(true);f.set(target,value);}
    static void invoke(Object target,String name)throws Exception{Method m=target.getClass().getDeclaredMethod(name);m.setAccessible(true);m.invoke(target);}
    interface Work{void run()throws Exception;}
    static void run(RuntimeInstrumentation test)throws Exception{
        Context context=test.getTargetContext();Store store=new Store(context);
        SharedPreferences prefs=context.getSharedPreferences("teno",0);
        String strong="00:00:00:00:07:11",weak="00:00:00:00:07:12";
        Map<String,Object> saved=new HashMap<>();
        for(String key:Arrays.asList("jwd.key."+strong,"jwd.key."+weak,"jwd.last_address","jwd.last_name"))saved.put(key,prefs.getAll().get(key));
        String snapshot=JwdService.snapshot;
        JwdService service=new JwdService();Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(service,context);
        test.runOnMainSync(service::onCreate);Handler handler=(Handler)get(service,"handler");
        List<String> probes=new CopyOnWriteArrayList<>(),connections=new CopyOnWriteArrayList<>(),commands=new CopyOnWriteArrayList<>();
        java.util.function.Consumer<Work> call=work->{CountDownLatch done=new CountDownLatch(1);AtomicReference<Throwable> error=new AtomicReference<>();handler.post(()->{try{work.run();}catch(Throwable e){error.set(e);}finally{done.countDown();}});try{if(!done.await(5,TimeUnit.SECONDS))throw new Exception("Handler timeout");if(error.get()!=null)throw new Exception(error.get());}catch(Exception e){throw new RuntimeException(e);}};
        try{
            prefs.edit().remove("jwd.key."+strong).remove("jwd.key."+weak).commit();
            call.accept(()->{
                set(service,"ble",new JwdTransport(){public void connect(BluetoothDevice d){connections.add(d.getAddress());}public void probe(BluetoothDevice d){probes.add(d.getAddress());}public void close(){}public void send(String v){commands.add(v);}});
                @SuppressWarnings("unchecked") Map<String,JSONObject> found=(Map<String,JSONObject>)get(service,"found");
                found.put(strong,new JSONObject().put("address",strong).put("name","HQ-10_P_STRONG").put("rssi",-30));
                found.put(weak,new JSONObject().put("address",weak).put("name","HQ-10_P_WEAK").put("rssi",-80));
                set(service,"autoDiscovery",true);set(service,"scanning",true);set(service,"preferredRecorder","");invoke(service,"selectAutomaticRecorder");
            });
            test.check(probes.equals(Arrays.asList(strong)),"first_connection_probes_strongest_candidate");
            test.check(store.deviceKey(strong).isEmpty()&&commands.isEmpty(),"name_and_rssi_do_not_generate_or_send_device_code");
            call.accept(()->service.serviceChecked(false,"Unsupported synthetic device"));
            test.check(probes.equals(Arrays.asList(strong,weak))&&store.deviceKey(strong).isEmpty(),"unsupported_protocol_is_skipped_without_binding");
            call.accept(()->service.serviceChecked(true,"Verified synthetic JWD"));
            String key=store.deviceKey(weak);
            test.check(JwdProtocol.validKey(key)&&connections.equals(Arrays.asList(weak)),"verified_device_gets_persisted_secure_code_before_connect");
            call.accept(service::ready);
            test.check(commands.contains("APP&SK&"+key),"authorization_reads_the_saved_code");
            call.accept(()->service.command("MCU&SK&ERR".getBytes(java.nio.charset.StandardCharsets.US_ASCII)));
            test.check(store.deviceKey(weak).equals(key)&&connections.size()==1,"rejected_code_is_preserved_without_reset_or_fallthrough");
            JSONObject state=new JSONObject(JwdService.snapshot);
            test.check(state.getJSONArray("devices").length()==1&&state.getJSONArray("devices").getJSONObject(0).optBoolean("key_rejected"),"only_verified_device_state_reaches_shared_ui");
            call.accept(()->{set(service,"autoDiscovery",true);set(service,"autoProbing",false);set(service,"scanning",true);set(service,"preferredRecorder",weak);((Set<?>)get(service,"autoTried")).clear();invoke(service,"selectAutomaticRecorder");});
            test.check(probes.get(probes.size()-1).equals(weak),"last_successful_device_has_priority_over_stronger_rssi");
            call.accept(()->service.serviceChecked(true,"Verified again"));
            test.check(store.deviceKey(weak).equals(key),"reconnect_reuses_original_device_code");
            call.accept(()->{invoke(service,"cancelAutomaticConnection");set(service,"pending","probe");service.serviceChecked(true,"Late verification");});
            test.check(connections.size()==2,"cancel_fences_late_verified_callback");
            test.check(commands.stream().noneMatch(v->v.equals("APP&STA")||v.contains("RESET")),"automatic_connection_never_records_or_resets");
            BluetoothGattService gatt=new BluetoothGattService(JwdProtocol.SERVICE,BluetoothGattService.SERVICE_TYPE_PRIMARY);
            BluetoothGattCharacteristic write=new BluetoothGattCharacteristic(JwdProtocol.WRITE,BluetoothGattCharacteristic.PROPERTY_WRITE,0);gatt.addCharacteristic(write);
            BluetoothGattCharacteristic audio=new BluetoothGattCharacteristic(JwdProtocol.AUDIO,BluetoothGattCharacteristic.PROPERTY_NOTIFY,0),command=new BluetoothGattCharacteristic(JwdProtocol.COMMAND,BluetoothGattCharacteristic.PROPERTY_NOTIFY,0);
            gatt.addCharacteristic(audio);gatt.addCharacteristic(command);
            test.check(!JwdBle.matchesProfile(gatt),"jwd_uuid_without_notification_descriptors_is_rejected");
            audio.addDescriptor(new BluetoothGattDescriptor(JwdProtocol.CCCD,0));command.addDescriptor(new BluetoothGattDescriptor(JwdProtocol.CCCD,0));
            test.check(JwdBle.matchesProfile(gatt),"complete_writable_and_notifiable_jwd_profile_is_verified");
            test.check(!JwdBle.matchesProfile(new BluetoothGattService(UUID.randomUUID(),0)),"unrelated_service_is_rejected");
        }finally{
            test.runOnMainSync(service::onDestroy);((Thread)get(service,"thread")).join(3000);JwdService.snapshot=snapshot;
            SharedPreferences.Editor edit=prefs.edit();for(Map.Entry<String,Object> item:saved.entrySet()){if(item.getValue()==null)edit.remove(item.getKey());else edit.putString(item.getKey(),(String)item.getValue());}edit.commit();
        }
    }
}
