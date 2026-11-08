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

/** Synthetic BLE replies and a loopback WebSocket, never physical-device or Azure evidence. */
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
        JwdLiveSession previousLive=JwdService.live;
        try(PreviewServer server=new PreviewServer()){
            store.base("http://127.0.0.1:"+server.server.getLocalPort());
            service=new JwdService();Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(service,context);
            test.runOnMainSync(service::onCreate);handler=(Handler)get(service,"handler");
            onService(()->{
                set(service,"ble",new JwdTransport(){public void connect(BluetoothDevice d){}public void probe(BluetoothDevice d){}public void close(){}public void send(String value){commands.add(value);}});
                set(service,"address",address);set(service,"deviceName","HQ-10_P_FIXTURE");
                set(service,"connected",true);set(service,"authorized",true);set(service,"recordState",0);
            });
            test.check(JwdProtocol.candidateName("HQ-10_P_FIXTURE")&&JwdProtocol.candidateName("hq-11_p_fixture")&&JwdProtocol.candidateName("KIOLO_FIXTURE"),"jwd_vendor_names_are_candidates");
            test.check(!JwdProtocol.candidateName("Headphones")&&!JwdProtocol.candidateName(null),"unrelated_names_are_not_jwd_matches");
            action("start",false);
            test.check(commands.contains("APP&STA")&&activity.runtime.state().getCapture().getPhase().equals("starting"),"start_waits_for_device_confirmation");
            reply("MCU&STA&clock-fixture.opus");
            long first=elapsed();String unchanged=JwdService.snapshot;Thread.sleep(1250);
            test.check(elapsed()-first>=1100&&JwdService.snapshot.equals(unchanged),"jwd_clock_advances_without_additional_ble_events");
            test.check(preview().contains("off"),"disabled_live_preference_is_visible");
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

            // Start a fresh preview through the same service command path as the release UI.
            action("start",true);reply("MCU&STA&preview-fixture.opus");
            test.until(()->{if(JwdService.live!=null&&!JwdService.live.problem.isEmpty())throw new IOException(JwdService.live.problem);return JwdService.live!=null&&JwdService.live.transcriber.status.startsWith("Live");});
            test.check(preview().startsWith("Waiting for recorder audio"),"connected_preview_does_not_claim_audio_has_arrived");
            test.check(server.automatic&&server.preview,"jwd_preview_requests_automatic_language_and_preview_only");
            byte[] frame;try(InputStream in=test.getContext().getAssets().open("jwd-synthetic-opus.bin")){frame=in.readAllBytes();}
            test.check(frame.length==80&&JwdAudio.opusFrame(frame),"synthetic_opus_fixture_is_valid");
            byte[] audio=new byte[80*50];for(int i=0;i<audio.length;i+=80)System.arraycopy(frame,0,audio,i,80);
            for(int at=0;at<audio.length;at+=244){byte[] part=Arrays.copyOfRange(audio,at,Math.min(at+244,audio.length));onService(()->service.audio(part));}
            test.until(()->JwdService.live.samples==16000&&server.pcm.get()==32000&&JwdService.live.transcriber.segments().length()==1);
            test.check(JwdService.live.receivedBytes==4000,"fragmented_jwd_stream_decodes_all_samples_and_streams_pcm");
            test.check(activity.runtime.state().getCapture().getSegmentsJson().contains("Synthetic preview result"),"live_transcript_reaches_flutter_bridge");
            action("pause",false);reply("MCU&PAUSE");test.until(()->server.paused);
            test.check(preview().equals("Preview paused"),"pause_is_visible_and_reaches_websocket");
            action("resume",false);reply("MCU&RESUME");test.until(()->server.resumed);
            test.check(preview().startsWith("Live"),"resume_restores_live_preview");
            byte[] damaged=new byte[80];onService(()->service.audio(damaged));test.until(()->JwdService.live.finished);
            test.check(preview().contains("unsupported or damaged"),"decoder_failure_is_visible_instead_of_blank_transcript");
            test.check(activity.runtime.state().getCapture().getPhase().equals("recording"),"preview_failure_does_not_stop_hardware_recording");
            test.check(new JSONObject(JwdService.snapshot).optString("last_draft").isEmpty(),"preview_does_not_replace_verified_complete_file");
            action("stop",false);reply("MCU&STO");
            server.busy=true;action("start",true);reply("MCU&STA&busy-fixture.opus");
            test.until(()->JwdService.live.transcriber.status.contains("busy"));
            test.check(preview().contains("Transcription service busy"),"backend_busy_reason_is_visible_in_preview");
            action("stop",false);reply("MCU&STO");test.until(()->JwdService.live.finished);
        }finally{
            if(service!=null){test.runOnMainSync(service::onDestroy);((Thread)get(service,"thread")).join(3000);}
            JwdService.snapshot=previous;JwdService.live=previousLive;store.base(base);store.pendingDeviceRecord(address,pending);
        }
    }

    /** Minimal RFC 6455 loopback peer. Text is a fixed fixture, not speech recognition. */
    private static final class PreviewServer implements AutoCloseable {
        final ServerSocket server=new ServerSocket(0,8,InetAddress.getByName("127.0.0.1"));
        final AtomicInteger pcm=new AtomicInteger();
        final List<Socket> sockets=new CopyOnWriteArrayList<>();
        volatile boolean automatic,preview,paused,resumed,busy;
        PreviewServer()throws IOException{
            Thread accept=new Thread(()->{while(!server.isClosed())try{Socket socket=server.accept();sockets.add(socket);new Thread(()->serve(socket),"PreviewFixtureClient").start();}catch(IOException ignored){break;}},"PreviewFixtureServer");accept.start();
        }
        private static String line(InputStream in)throws IOException{ByteArrayOutputStream b=new ByteArrayOutputStream();int c;while((c=in.read())>=0&&c!=10)if(c!=13)b.write(c);return b.toString("UTF-8");}
        private static void send(OutputStream out,String text)throws IOException{
            byte[] b=text.getBytes(StandardCharsets.UTF_8);out.write(0x81);if(b.length<126)out.write(b.length);else{out.write(126);out.write(b.length>>8);out.write(b.length);}out.write(b);out.flush();
        }
        private void serve(Socket socket){
            try(socket){
                socket.setSoTimeout(15000);InputStream in=socket.getInputStream();OutputStream out=socket.getOutputStream();String request=line(in);Map<String,String> headers=new HashMap<>();
                for(String row;(row=line(in))!=null&&!row.isEmpty();){int p=row.indexOf(':');if(p>0)headers.put(row.substring(0,p).toLowerCase(Locale.ROOT),row.substring(p+1).trim());}
                if(headers.containsKey("sec-websocket-key")){
                    String accept=Base64.getEncoder().encodeToString(MessageDigest.getInstance("SHA-1").digest((headers.get("sec-websocket-key")+"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").getBytes(StandardCharsets.US_ASCII)));
                    out.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "+accept+"\r\n\r\n").getBytes(StandardCharsets.US_ASCII));
                    if(busy){send(out,"{\"type\":\"error\",\"code\":\"ASR_BUSY\"}");return;}
                    send(out,"{\"type\":\"ready\"}");boolean textSent=false;
                    while(true){
                        int first=in.read(),second=in.read();if(first<0||second<0)break;int length=second&127;if(length==126)length=(in.read()<<8)|in.read();else if(length==127)throw new IOException("Fixture frame too large");
                        byte[] mask=(second&128)!=0?in.readNBytes(4):new byte[0],body=in.readNBytes(length);if(body.length!=length)break;
                        if(mask.length==4)for(int i=0;i<body.length;i++)body[i]^=mask[i%4];int opcode=first&15;
                        if(opcode==2){pcm.addAndGet(body.length);if(!textSent){send(out,"{\"type\":\"partial\",\"text\":\"Synthetic partial\"}");send(out,"{\"type\":\"final\",\"id\":\"fixture-final\",\"start_ms\":0,\"end_ms\":1000,\"text\":\"Synthetic preview result\"}");textSent=true;}}
                        if(opcode==1){String kind=new JSONObject(new String(body,StandardCharsets.UTF_8)).optString("type");if(kind.equals("pause"))paused=true;else if(kind.equals("resume"))resumed=true;else if(kind.equals("stop")){send(out,"{\"type\":\"completed\"}");break;}}
                        if(opcode==8)break;
                    }
                }else{
                    byte[] body=in.readNBytes(Integer.parseInt(headers.getOrDefault("content-length","0")));String result="{}";
                    if(request.startsWith("POST /api/v1/realtime/sessions ")){JSONObject options=new JSONObject(new String(body,StandardCharsets.UTF_8));automatic=options.optString("language").equals("auto");preview=options.optBoolean("preview");result="{\"id\":\"loopback-preview\",\"websocket_path\":\"/api/v1/realtime/sessions/loopback-preview/stream\"}";}
                    byte[] bytes=result.getBytes(StandardCharsets.UTF_8);out.write(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+bytes.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));out.write(bytes);out.flush();
                }
            }catch(Exception ignored){/* Test assertions diagnose missing events, never log requests or tokens. */}
        }
        public void close()throws IOException{server.close();for(Socket socket:sockets)socket.close();}
    }
}
