package com.teno.app;

import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.os.*;
import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import static com.teno.app.RuntimeMessages.*;

/** Only installed on a dedicated emulator. No live account or provider requests. */
public final class RuntimeInstrumentation extends Instrumentation {
    private String mode;
    private final JSONArray checks=new JSONArray();
    private Context context;
    private Store store;
    interface Condition {boolean value()throws Exception;}
    void check(boolean condition,String name)throws Exception {
        checks.put(new JSONObject().put("name",name).put("passed",condition));
        if(!condition)throw new IOException(name);
    }
    void until(Condition condition)throws Exception {
        long end=SystemClock.elapsedRealtime()+30000;
        while(!condition.value()){if(SystemClock.elapsedRealtime()>end)throw new IOException("Native operation timed out");Thread.sleep(60);}
    }
    static String hash(byte[] bytes)throws Exception {
        StringBuilder out=new StringBuilder();for(byte b:MessageDigest.getInstance("SHA-256").digest(bytes))out.append(String.format(Locale.ROOT,"%02x",b));return out.toString();
    }
    @Override public void onCreate(Bundle args){super.onCreate(args);mode=args.getString("mode","full");start();}
    @Override public void onStart(){
        boolean passed=false;JSONObject report=new JSONObject();context=getTargetContext();store=new Store(context);
        try {
            if(!android.os.Build.HARDWARE.contains("ranchu")&&!android.os.Build.HARDWARE.contains("goldfish"))throw new IOException("Dedicated emulator required");
            if(mode.equals("seed"))seed();else new RuntimeChecks(this).run();
            passed=true;
        } catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        try {
            report.put("all_passed",passed).put("checks",checks).put("evidence","Dedicated API 35 emulator; synthetic account and loopback backend. No physical JWD, iPhone or Azure accuracy claims.");
            Files.write(new File(context.getExternalFilesDir(null),mode+"-runtime-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));
        } catch(Exception ignored){}
        Bundle result=new Bundle();result.putString("stream",report.toString());finish(passed?Activity.RESULT_OK:Activity.RESULT_CANCELED,result);
    }
    private void seed()throws Exception {
        if(!store.scope().isEmpty()&&!context.getSharedPreferences("teno",0).getBoolean("runtime_test_fixture",false))throw new IOException("Refusing to overwrite non-fixture account data");
        context.getSharedPreferences("teno",0).edit().putBoolean("runtime_test_fixture",true).commit();
        store.base("http://127.0.0.1:9");store.identity("Teno upgrade fixture","cross-platform-upgrade");
        store.tokens(new JSONObject().put("access_token","upgrade-loopback-fixture").put("refresh_token","refresh-loopback-fixture"));
        store.recordingOptions(false,false,false);store.markNativePreferences();
        String address="00:00:00:00:05:00",key=JwdProtocol.newKey();
        store.deviceKey(address,key);store.rememberRecorder(address,"Verification recorder");
        JSONObject draft=store.newDraft("Teno upgrade audio",".wav");File file=new File(draft.getString("path"));
        try(FileOutputStream out=new FileOutputStream(file)){out.write(JwdAudio.wavHeader(32000));out.write(new byte[32000]);}
        draft.put("duration_ms",1000).put("upload_requested",true).put("upload_automatic",false)
            .put("upload_attempts",1).put("upload_retry_at",System.currentTimeMillis()+86400000).put("status","queued");
        store.save(draft);
        JSONObject expected=new JSONObject().put("id",draft.getString("id")).put("scope",store.scope()).put("address",address)
            .put("key_hash",hash(key.getBytes(StandardCharsets.UTF_8))).put("audio_hash",hash(Files.readAllBytes(file.toPath())));
        Files.write(new File(context.getFilesDir(),"upgrade-fixture.json").toPath(),expected.toString().getBytes(StandardCharsets.UTF_8));
        check(context.getPackageManager().getPackageInfo(context.getPackageName(),0).versionName.equals("0.4.4"),"seed_runs_inside_original_0_4_4");
        check(!store.token("access_token").isEmpty(),"old_keystore_session_saved");
        check(store.drafts().length()>0,"old_audio_and_pending_queue_saved");
    }
    /** Kept separate so the seed runner can execute against the original APK's classes. */
    private static final class RuntimeChecks {
        final RuntimeInstrumentation test;Context context;Store store;MainActivity activity;ServerSocket server;
        final AtomicInteger uploadCount=new AtomicInteger();final List<String> clientIds=new CopyOnWriteArrayList<>();
        volatile boolean failUpload;
        volatile boolean blockUpload, uploadWaiting;
        RuntimeChecks(RuntimeInstrumentation test){this.test=test;context=test.context;store=test.store;}
        interface VoidCall{void call(VoidResult result);}
        void call(VoidCall call)throws Exception {
            CountDownLatch done=new CountDownLatch(1);AtomicReference<Throwable> error=new AtomicReference<>();
            test.runOnMainSync(()->call.call(new VoidResult(){public void success(){done.countDown();}public void error(Throwable e){error.set(e);done.countDown();}}));
            if(!done.await(35,TimeUnit.SECONDS))throw new IOException("Bridge request timed out");
            if(error.get()!=null)throw new IOException(error.get().getMessage());
        }
        void run()throws Exception {
            try {
                JSONObject expected=new JSONObject(new String(Files.readAllBytes(new File(context.getFilesDir(),"upgrade-fixture.json").toPath()),StandardCharsets.UTF_8));
                String oldId=expected.getString("id"),owner=expected.getString("scope");
                if(test.mode.equals("regression")){
                    if(!context.getSharedPreferences("teno",0).getBoolean("runtime_test_fixture",false))throw new IOException("A previously seeded test emulator is required");
                    store.base("http://127.0.0.1:9");store.identity("Teno upgrade fixture","cross-platform-upgrade");
                    store.tokens(new JSONObject().put("access_token","upgrade-loopback-fixture").put("refresh_token","refresh-loopback-fixture"));
                    UploadQueue.resumeAccount(context);
                }
                if(!test.mode.equals("regression")){
                test.check(store.scope().equals(owner)&&store.name().equals("Teno upgrade fixture"),"upgrade_preserves_account_scope");
                test.check(store.token("access_token").equals("upgrade-loopback-fixture"),"upgrade_decrypts_original_session");
                test.check(hash(store.deviceKey(expected.getString("address")).getBytes(StandardCharsets.UTF_8)).equals(expected.getString("key_hash")),"upgrade_decrypts_original_device_key");
                JSONObject old=store.draft(oldId);
                test.check(hash(Files.readAllBytes(new File(old.getString("path")).toPath())).equals(expected.getString("audio_hash")),"upgrade_keeps_audio_bytes");
                test.check(old.optBoolean("upload_requested")&&old.optInt("upload_attempts")==1&&old.getString("id").equals(oldId),"upgrade_keeps_pending_queue_and_client_id");
                }
                server();store.base("http://127.0.0.1:"+server.getLocalPort());
                test.getUiAutomation().executeShellCommand("pm grant "+context.getPackageName()+" android.permission.RECORD_AUDIO").close();
                test.getUiAutomation().executeShellCommand("pm grant "+context.getPackageName()+" android.permission.POST_NOTIFICATIONS").close();
                activity=(MainActivity)test.startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                test.until(()->activity.runtime!=null);Thread.sleep(2500);
                test.check(activity.runtime.state().getSession().getSignedIn(),"flutter_host_reads_native_session");
                test.check(!activity.runtime.state().getDraftsJson().contains("\"path\""),"bridge_does_not_expose_private_file_paths");
                screenshot("01-home-upgrade");
                CountDownLatch started=new CountDownLatch(1);AtomicReference<String> id=new AtomicReference<>();AtomicReference<Throwable> error=new AtomicReference<>();
                test.runOnMainSync(()->activity.runtime.startPhone("Teno native recording verification",new Result<String>(){
                    public void success(String value){id.set(value);started.countDown();}public void error(Throwable e){error.set(e);started.countDown();}}));
                if(!started.await(30,TimeUnit.SECONDS)||error.get()!=null)throw new IOException("Phone recording could not start");
                test.until(()->RecorderService.active&&RecorderService.capturedBytes>=16000);
                call(result->activity.runtime.saveNotes(id.get(),"00:01 · Verification highlight",result));
                call(result->activity.runtime.controlPhone(PhoneAction.PAUSE,result));
                test.until(()->RecorderService.paused);long count=RecorderService.capturedBytes;Thread.sleep(800);
                test.check(RecorderService.capturedBytes==count,"pause_does_not_append_audio");
                call(result->activity.runtime.controlPhone(PhoneAction.RESUME,result));
                test.until(()->RecorderService.capturedBytes>count+3200);
                // Background activity lifecycle must not stop the native recording service.
                test.getUiAutomation().executeShellCommand("input keyevent KEYCODE_HOME").close();Thread.sleep(900);
                test.check(RecorderService.active&&RecorderService.capturedBytes>count+6400,"recording_continues_when_flutter_is_backgrounded");
                test.getUiAutomation().executeShellCommand("am start -n "+context.getPackageName()+"/com.teno.app.MainActivity").close();Thread.sleep(500);
                call(result->activity.runtime.controlPhone(PhoneAction.STOP,result));
                test.until(()->!RecorderService.active&&!RecorderService.finishing);
                JSONObject draft=store.draft(id.get());File file=new File(draft.getString("path"));
                test.check(file.isFile()&&file.length()>32044&&draft.optString("status").equals("local"),"stop_retains_complete_local_wave_without_cloud");
                test.check(draft.optString("notes").contains("Verification highlight"),"timestamped_note_saved_with_draft");
                call(result->activity.runtime.playback(PlaybackAction.PLAY,id.get(),true,0L,1.0,result));
                test.until(()->activity.runtime.media.state().getReady());
                test.check(activity.runtime.media.state().getDurationMs()>500,"local_wave_is_playable");
                call(result->activity.runtime.playback(PlaybackAction.PAUSE,id.get(),true,0L,1.0,result));
                failUpload=true;call(result->activity.runtime.retryUpload(id.get(),result));
                test.until(()->uploadCount.get()>0&&!UploadQueue.running.get());
                test.check(store.draft(id.get()).optBoolean("upload_requested")&&file.isFile(),"temporary_upload_failure_is_durable_and_keeps_audio");
                failUpload=false;call(result->activity.runtime.retryUpload(id.get(),result));
                test.until(()->!store.draft(id.get()).optString("recording_id").isEmpty()&&!UploadQueue.running.get());
                test.check(clientIds.size()>=2&&clientIds.stream().allMatch(v->v.equals(id.get())),"retry_reuses_original_client_id");
                test.check(file.isFile(),"successful_upload_preserves_local_original");
                call(result->activity.runtime.retryUpload(id.get(),result));Thread.sleep(200);
                test.check(uploadCount.get()==2,"completed_upload_is_not_enqueued_again");
                JwdService.snapshot=new JSONObject().put("record_state",-1).put("record_name","unconfirmed.opus").put("address","00:00:00:00:05:00")
                    .put("message","Connection interrupted. Recorder may still be recording.").toString();
                test.check(activity.runtime.state().getCapture().getPhase().equals("interrupted"),"device_disconnect_never_claims_stopped");
                JwdService.snapshot="{}";
                JSONObject pending=store.newDraft("Account switch upload fixture",".wav");String pendingId=pending.getString("id");
                try(FileOutputStream out=new FileOutputStream(new File(pending.getString("path")))){out.write(JwdAudio.wavHeader(32000));out.write(new byte[32000]);}
                pending.put("status","local").put("duration_ms",1000);store.save(pending);
                blockUpload=true;call(result->activity.runtime.retryUpload(pendingId,result));test.until(()->uploadWaiting);
                call(result->activity.runtime.logout(result));
                test.check(store.scope().isEmpty(),"sign_out_clears_visible_account");
                test.check(!UploadQueue.running.get(),"sign_out_stops_active_native_upload");
                store.identity("other fixture","other-account");
                test.check(store.drafts().length()==0,"other_account_cannot_see_original_drafts");
                store.base("http://127.0.0.1:9");store.identity("Teno upgrade fixture","cross-platform-upgrade");
                test.check(store.draft(oldId).getString("id").equals(oldId),"returning_account_keeps_pending_original_recording");
                test.check(store.draft(pendingId).optBoolean("upload_requested")&&new File(store.draft(pendingId).getString("path")).isFile(),"account_switch_preserves_paused_upload_and_local_audio");
                store.logout();
                screenshot("02-runtime-finished");
            } finally {
                if(RecorderService.active)context.startService(new Intent(context,RecorderService.class).setAction("stop"));
                if(activity!=null)test.runOnMainSync(activity::finish);
                if(server!=null)server.close();
            }
        }
        void screenshot(String name)throws Exception {
            try(FileOutputStream out=new FileOutputStream(new File(context.getExternalFilesDir(null),name+".png"))){
                test.getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);
            }
        }
        static String line(InputStream in)throws Exception {
            ByteArrayOutputStream out=new ByteArrayOutputStream();int value;
            while((value=in.read())!=-1&&value!='\n')if(value!='\r')out.write(value);
            return out.toString("UTF-8");
        }
        void server()throws Exception {
            server=new ServerSocket(0,8,InetAddress.getByName("127.0.0.1"));
            Thread thread=new Thread(()->{while(!server.isClosed())try {
                Socket socket=server.accept();
                new Thread(()->{try(socket) {
                    socket.setSoTimeout(15000);InputStream input=socket.getInputStream();String[] request=line(input).split(" ");
                    Map<String,String> headers=new HashMap<>();String item;
                    while(!(item=line(input)).isEmpty()){int p=item.indexOf(':');headers.put(item.substring(0,p).toLowerCase(Locale.ROOT),item.substring(p+1).trim());}
                    ByteArrayOutputStream body=new ByteArrayOutputStream();
                    if("chunked".equalsIgnoreCase(headers.get("transfer-encoding"))){
                        while(true){int count=Integer.parseInt(line(input).split(";")[0],16);if(count==0){line(input);break;}body.write(input.readNBytes(count));line(input);}
                    } else if(headers.containsKey("content-length"))body.write(input.readNBytes(Integer.parseInt(headers.get("content-length"))));
                    JSONObject answer=new JSONObject().put("items",new JSONArray());int status=200;String path=request[1];
                    if(path.equals("/api/v1/recordings")&&request[0].equals("POST")){
                        uploadCount.incrementAndGet();String content=body.toString("ISO-8859-1"),marker="name=\"client_id\"\r\n\r\n";int start=content.indexOf(marker)+marker.length();
                        clientIds.add(content.substring(start,content.indexOf("\r\n",start)));
                        if(blockUpload){uploadWaiting=true;Thread.sleep(6000);}
                        status=failUpload?503:200;answer=failUpload?new JSONObject().put("message","Temporary fixture outage"):new JSONObject().put("recording_id","cloud-fixture").put("job_id","job-fixture");
                    } else if(path.equals("/api/v1/auth/logout"))answer=new JSONObject().put("ok",true);
                    byte[] bytes=answer.toString().getBytes(StandardCharsets.UTF_8);OutputStream out=socket.getOutputStream();
                    out.write(("HTTP/1.1 "+status+" Result\r\nContent-Type: application/json\r\nContent-Length: "+bytes.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));out.write(bytes);out.flush();
                }catch(Exception ignored){}},"LoopbackRequest").start();
            }catch(Exception ignored){}},"LoopbackServer");
            thread.setDaemon(true);thread.start();
        }
    }
}
