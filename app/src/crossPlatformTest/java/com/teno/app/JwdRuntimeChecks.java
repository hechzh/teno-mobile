package com.teno.app;

import android.bluetooth.BluetoothDevice;
import android.content.*;
import android.os.*;
import org.json.*;
import java.io.*;
import java.lang.reflect.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** Synthetic BLE replies and a loopback connection detector; no provider or physical-device evidence. */
final class JwdRuntimeChecks {
    private final RuntimeInstrumentation test;
    private final MainActivity activity;
    private final Context context;
    private final Store store;
    private JwdService service;
    private Handler handler;
    private final List<String> commands=new CopyOnWriteArrayList<>();
    private final String address="00:00:00:00:06:02";
    JwdRuntimeChecks(RuntimeInstrumentation test,MainActivity activity){
        this.test=test;this.activity=activity;context=test.getTargetContext();store=new Store(context);
    }
    private interface Work {void run()throws Exception;}
    private static Object get(Object target,String name)throws Exception{Field f=target.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(target);}
    private static void set(Object target,String name,Object value)throws Exception{Field f=target.getClass().getDeclaredField(name);f.setAccessible(true);f.set(target,value);}
    private void onService(Work work)throws Exception{
        CountDownLatch done=new CountDownLatch(1);AtomicReference<Throwable> error=new AtomicReference<>();
        handler.post(()->{try{work.run();}catch(Throwable e){error.set(e);}finally{done.countDown();}});
        if(!done.await(5,TimeUnit.SECONDS))throw new IOException("Recorder handler timed out");
        if(error.get()!=null)throw new IOException(error.get());
    }
    private void action(String name,boolean live)throws Exception{
        onService(()->{Method m=JwdService.class.getDeclaredMethod("handle",Intent.class);m.setAccessible(true);m.invoke(service,new Intent().setAction(name).putExtra("live",live));});
    }
    private void reply(String text)throws Exception{onService(()->service.command(text.getBytes(StandardCharsets.US_ASCII)));}
    private long elapsed()throws Exception{return activity.runtime.state().getCapture().getElapsedMs();}
    private String preview()throws Exception{return activity.runtime.state().getCapture().getPreviewStatus();}
    void run()throws Exception{
        String previous=JwdService.snapshot,base=store.base(),pending=store.pendingDeviceRecord(address);
        try(PreviewServer server=new PreviewServer()){
            store.base("http://127.0.0.1:"+server.server.getLocalPort());
            service=new JwdService();Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(service,context);
            test.runOnMainSync(service::onCreate);handler=(Handler)get(service,"handler");
            onService(()->{
                set(service,"ble",new JwdTransport(){public void connect(BluetoothDevice d){}public void probe(BluetoothDevice d){}public void close(){}public void send(String value){commands.add(value);}});
                set(service,"address",address);set(service,"deviceName","HQ-10_P_FIXTURE");
                set(service,"connected",true);set(service,"authorized",true);set(service,"recordState",0);
                ((RecorderOwnership)get(service,"ownership")).state="owned";
            });
            test.check(JwdProtocol.candidateName("HQ-10_P_FIXTURE")&&JwdProtocol.candidateName("hq-11_p_fixture")&&JwdProtocol.candidateName("KIOLO_FIXTURE"),"jwd_vendor_names_are_candidates");
            test.check(!JwdProtocol.candidateName("Headphones")&&!JwdProtocol.candidateName(null),"unrelated_names_are_not_jwd_matches");
            action("start",false);
            test.check(commands.contains("APP&STA")&&activity.runtime.state().getCapture().getPhase().equals("starting"),"start_waits_for_device_confirmation");
            reply("MCU&STA&clock-fixture.opus");
            long first=elapsed();String unchanged=JwdService.snapshot;Thread.sleep(1250);
            test.check(elapsed()-first>=1100&&JwdService.snapshot.equals(unchanged),"jwd_clock_advances_without_additional_ble_events");
            test.check(preview().isEmpty(),"recording_has_no_preview_status");
            action("pause",false);reply("MCU&PAUSE");long paused=elapsed();Thread.sleep(700);
            test.check(elapsed()==paused&&activity.runtime.state().getCapture().getPhase().equals("paused"),"jwd_clock_freezes_on_confirmed_pause");
            action("resume",false);reply("MCU&RESUME");Thread.sleep(800);long resumed=elapsed();
            test.check(resumed-paused>=700&&resumed-paused<1400,"jwd_clock_resumes_without_counting_pause");
            reply("MCU&RT&clock-fixture.opus&42");
            test.check(elapsed()>=42000&&elapsed()<42500,"device_time_query_reanchors_clock");
            test.runOnMainSync(activity.runtime::suspendUi);long background=elapsed();Thread.sleep(700);
            test.runOnMainSync(activity.runtime::resume);
            test.check(elapsed()-background>=600,"jwd_clock_catches_up_after_background");
            onService(()->service.closed("Synthetic disconnect"));long interrupted=elapsed();Thread.sleep(500);
            test.check(elapsed()==interrupted&&interrupted>=42000&&activity.runtime.state().getCapture().getPhase().equals("interrupted"),"disconnect_freezes_last_confirmed_clock_and_reports_uncertainty");
            onService(()->{set(service,"connected",true);set(service,"authorized",true);});
            reply("MCU&RT&clock-fixture.opus&60");
            test.check(elapsed()>=60000&&elapsed()<60500,"reconnect_uses_reported_device_duration");
            action("stop",false);reply("MCU&STO");
            test.check(new JSONObject(JwdService.snapshot).optInt("record_state")==0,"stop_requires_and_accepts_device_confirmation");

            // Legacy clients/settings cannot reactivate audio streaming.
            context.getSharedPreferences("teno",0).edit().putBoolean("live_default",true).commit();
            test.check(!store.liveDefault(),"old_live_on_preference_is_ignored");
            action("start",true);reply("MCU&STA&post-recording-fixture.opus");
            int drafts=store.drafts().length();
            onService(()->service.audio(new byte[4000]));Thread.sleep(400);
            test.check(server.connections.get()==0,"legacy_live_intent_and_audio_do_not_connect_to_transcription");
            test.check(activity.runtime.state().getCapture().getPartial().isEmpty()&&activity.runtime.state().getCapture().getSegmentsJson().equals("[]")&&preview().isEmpty(),"native_bridge_never_exposes_recording_time_transcript");
            test.check(store.drafts().length()==drafts&&new JSONObject(JwdService.snapshot).optString("last_draft").isEmpty(),"live_packets_cannot_replace_verified_saved_file");
            action("pause",true);reply("MCU&PAUSE");action("resume",true);reply("MCU&RESUME");
            test.check(activity.runtime.state().getCapture().getPhase().equals("recording")&&server.connections.get()==0,"pause_and_resume_work_without_transcription_connection");
            action("stop",true);reply("MCU&STO");
            test.check(new JSONObject(JwdService.snapshot).optInt("record_state")==0&&server.connections.get()==0,"stop_waits_for_file_sync_without_live_session");
        }finally{
            if(service!=null){test.runOnMainSync(service::onDestroy);((Thread)get(service,"thread")).join(3000);}
            JwdService.snapshot=previous;store.base(base);store.pendingDeviceRecord(address,pending);
        }
    }

    /** Any HTTP/WebSocket connection during the capture fails the test. */
    private static final class PreviewServer implements AutoCloseable {
        final ServerSocket server=new ServerSocket(0,8,InetAddress.getByName("127.0.0.1"));
        final AtomicInteger connections=new AtomicInteger();
        final Thread thread;
        PreviewServer()throws IOException{
            thread=new Thread(()->{while(!server.isClosed())try(Socket socket=server.accept()){connections.incrementAndGet();}catch(IOException ignored){}});
            thread.start();
        }
        public void close()throws IOException{server.close();try{thread.join(2000);}catch(InterruptedException e){Thread.currentThread().interrupt();}}
    }
}
