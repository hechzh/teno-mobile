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
        for(String key:Arrays.asList("jwd.key."+strong,"jwd.key."+weak,"jwd.last_address","jwd.last_name","scope","username","session","server"))saved.put(key,prefs.getAll().get(key));
        String snapshot=JwdService.snapshot;
        JwdService service=new JwdService();Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(service,context);
        test.runOnMainSync(service::onCreate);Handler handler=(Handler)get(service,"handler");
        List<String> probes=new CopyOnWriteArrayList<>(),connections=new CopyOnWriteArrayList<>(),commands=new CopyOnWriteArrayList<>();
        java.util.function.Consumer<Work> call=work->{CountDownLatch done=new CountDownLatch(1);AtomicReference<Throwable> error=new AtomicReference<>();handler.post(()->{try{work.run();}catch(Throwable e){error.set(e);}finally{done.countDown();}});try{if(!done.await(5,TimeUnit.SECONDS))throw new Exception("Handler timeout");if(error.get()!=null)throw new Exception(error.get());}catch(Exception e){throw new RuntimeException(e);}};
        try{
            store.logout();JwdService.accountClosing=false;
            Method handle=JwdService.class.getDeclaredMethod("handle",Intent.class);handle.setAccessible(true);
            for(String action:Arrays.asList("scan","scan_compat","probe","connect")){
                boolean rejected=false;try{handle.invoke(service,new Intent().setAction(action));}catch(InvocationTargetException e){rejected=e.getCause() instanceof java.io.IOException;}
                test.check(rejected,"signed_out_service_rejects_"+action);
            }
            store.base("http://127.0.0.1:9");store.identity("Synthetic JWD login gate","jwd-auth-fixture-"+System.nanoTime());
            store.tokens(new JSONObject().put("access_token","synthetic-jwd-fixture"));
            prefs.edit().remove("jwd.key."+strong).remove("jwd.key."+weak).commit();
            call.accept(()->{
                set(service,"connectionOwner",store.scope());set(service,"connectionEpoch",JwdService.sessionEpoch.get());JwdService.accountClosing=false;
                set(service,"ble",new JwdTransport(){public void connect(BluetoothDevice d){connections.add(d.getAddress());}public void probe(BluetoothDevice d){probes.add(d.getAddress());}public void close(){}public void send(String v){commands.add(v);}});
                @SuppressWarnings("unchecked") Map<String,JSONObject> found=(Map<String,JSONObject>)get(service,"found");
                found.put(strong,new JSONObject().put("address",strong).put("name","HQ-10_P_STRONG").put("rssi",-30));
                found.put(weak,new JSONObject().put("address",weak).put("name","HQ-10_P_WEAK").put("rssi",-80));
                found.put("00:00:00:00:07:13",new JSONObject().put("address","00:00:00:00:07:13").put("name","Unrecognized").put("rssi",-19));
                set(service,"autoDiscovery",true);set(service,"scanning",true);set(service,"preferredRecorder","");invoke(service,"selectAutomaticRecorder");
            });
            test.check(probes.equals(Arrays.asList(strong)),"first_connection_probes_strongest_candidate");
            test.check(store.deviceKey(strong).isEmpty()&&commands.isEmpty(),"name_and_rssi_do_not_generate_or_send_device_code");
            call.accept(()->service.serviceChecked(false,"Unsupported synthetic device"));
            test.check(probes.equals(Arrays.asList(strong,weak))&&store.deviceKey(strong).isEmpty(),"unsupported_protocol_is_skipped_without_binding");
            call.accept(()->service.serviceChecked(true,"Verified synthetic JWD"));
            test.check(store.deviceKey(weak).isEmpty()&&connections.equals(Arrays.asList(weak)),"verified_profile_connects_without_generating_a_new_code");
            String key=JwdProtocol.newKey();store.deviceKey(weak,key);store.recorderIdentity(weak,new JSONObject().put("hardware_id","A0B1C2D3E4F5").put("id","fixture-owned"));
            call.accept(service::ready);
            test.until(()->commands.contains("APP&MAC"));
            test.check(commands.contains("APP&MAC")&&commands.stream().noneMatch(v->v.startsWith("APP&SK&")),"hardware_identity_precedes_key_authorization");
            call.accept(()->service.command("MCU&MAC&A0B1C2D3E4F5".getBytes(java.nio.charset.StandardCharsets.US_ASCII)));
            test.until(()->commands.contains("APP&SK&"+key));
            test.check(commands.contains("APP&SK&"+key),"authorization_reads_the_saved_code");
            call.accept(()->service.command("MCU&SK&ERR".getBytes(java.nio.charset.StandardCharsets.US_ASCII)));
            test.check(store.deviceKey(weak).equals(key)&&connections.size()==1,"rejected_code_is_preserved_without_reset_or_fallthrough");
            JSONObject state=new JSONObject(JwdService.snapshot);
            JSONArray rows=state.getJSONArray("devices");
            test.check(rows.length()==3&&rows.getJSONObject(1).optBoolean("key_rejected")&&"unsupported".equals(rows.getJSONObject(0).optString("gatt_status")),"shared_ui_distinguishes_unrecognized_unsupported_and_verified");
            call.accept(()->{set(service,"autoDiscovery",true);set(service,"autoProbing",false);set(service,"scanning",true);set(service,"preferredRecorder",weak);((Set<?>)get(service,"autoTried")).clear();invoke(service,"selectAutomaticRecorder");});
            test.check(probes.get(probes.size()-1).equals(weak),"last_successful_device_has_priority_over_stronger_rssi");
            call.accept(()->service.serviceChecked(true,"Verified again"));
            test.check(store.deviceKey(weak).equals(key),"reconnect_reuses_original_device_code");
            call.accept(()->{invoke(service,"cancelAutomaticConnection");set(service,"pending","probe");service.serviceChecked(true,"Late verification");});
            test.check(connections.size()==2,"cancel_fences_late_verified_callback");
            int beforeCommands=commands.size(), beforeConnections=connections.size(), beforeProbes=probes.size();
            JwdService.accountClosing=true;JwdService.sessionEpoch.incrementAndGet();
            call.accept(()->{set(service,"autoDiscovery",true);set(service,"autoProbing",true);set(service,"pending","probe");
                service.serviceChecked(true,"Late verification after logout");service.ready();
                set(service,"pending","auth");service.command("MCU&SK&OK".getBytes(java.nio.charset.StandardCharsets.US_ASCII));});
            test.check(commands.size()==beforeCommands&&connections.size()==beforeConnections&&probes.size()==beforeProbes,"logout_fences_late_probe_ready_and_auth_callbacks");
            test.check(!(boolean)get(service,"authorized"),"logout_cannot_restore_authorized_connection");
            JwdService.accountClosing=false;
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
            JwdService.accountClosing=false;
            test.runOnMainSync(service::onDestroy);((Thread)get(service,"thread")).join(3000);JwdService.snapshot=snapshot;
            SharedPreferences.Editor edit=prefs.edit();for(Map.Entry<String,Object> item:saved.entrySet()){if(item.getValue()==null)edit.remove(item.getKey());else edit.putString(item.getKey(),(String)item.getValue());}edit.commit();
        }
    }
}
