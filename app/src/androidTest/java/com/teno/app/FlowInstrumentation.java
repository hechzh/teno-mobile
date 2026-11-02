package com.teno.app;

import android.Manifest;
import android.app.*;
import android.app.job.JobScheduler;
import android.bluetooth.BluetoothDevice;
import android.content.*;
import android.graphics.*;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.lang.reflect.*;
import java.net.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.*;

/** Isolated UI, actual PCM capture, loopback uploads and synthetic recorder responses. */
public final class FlowInstrumentation extends Instrumentation {
    static FlowInstrumentation current;Context context;Store store;MainActivity main;TeamActivity team;JwdActivity device;
    JwdService recorder;Handler recorderHandler;FakeTransport transport;ServerSocket server;String runName,phoneId="";
    final JSONArray checks=new JSONArray(),screens=new JSONArray();final List<String> created=new ArrayList<>();
    final Map<String,Integer> uploads=new ConcurrentHashMap<>();final Set<String> failOnce=ConcurrentHashMap.newKeySet(),badRequest=ConcurrentHashMap.newKeySet();
    final Map<String,String> states=new ConcurrentHashMap<>();volatile Throwable asyncError;
    interface Condition{boolean value()throws Exception;}
    JSONObject json(Object... data)throws Exception{JSONObject o=new JSONObject();for(int i=0;i<data.length;i+=2)o.put((String)data[i],data[i+1]);return o;}
    @Override public void onCreate(Bundle args){super.onCreate(args);runName=args.getString("run","normal");current=this;start();}
    void check(boolean value,String name)throws Exception{checks.put(json("check",name,"passed",value));if(!value)throw new IOException(name);}
    void ui(Runnable action)throws Exception{runOnMainSync(action);waitForIdleSync();Thread.sleep(160);}
    void until(Condition condition)throws Exception{long end=SystemClock.elapsedRealtime()+15000;while(!condition.value()){if(asyncError!=null)throw new IOException(asyncError);if(SystemClock.elapsedRealtime()>end)throw new IOException("Timed out waiting for state");Thread.sleep(60);}waitForIdleSync();Thread.sleep(160);}
    void ready(MainActivity a)throws Exception{until(()->!a.loading&&MainActivity.pendingOperations.get()==0);}
    TextView find(View root,String text){if(root instanceof TextView&&((TextView)root).getText().toString().equals(text))return(TextView)root;if(root instanceof ViewGroup){ViewGroup g=(ViewGroup)root;for(int i=0;i<g.getChildCount();i++){TextView item=find(g.getChildAt(i),text);if(item!=null)return item;}}return null;}
    String words(View root){String s=root instanceof TextView?((TextView)root).getText()+"\n":"";if(root instanceof ViewGroup){ViewGroup g=(ViewGroup)root;for(int i=0;i<g.getChildCount();i++)s+=words(g.getChildAt(i));}return s;}
    void click(View root,String label)throws Exception{TextView button=find(root,label);check(button!=null&&button.isEnabled(),"action_available_"+label);ui(button::performClick);}
    void screen(String name)throws Exception{String file=runName+"-"+name+".png";try(FileOutputStream out=new FileOutputStream(new File(context.getFilesDir(),file))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}screens.put(file);}
    static void field(Object object,String name,Object value)throws Exception{Field f=object.getClass().getDeclaredField(name);f.setAccessible(true);f.set(object,value);}
    static Object field(Object object,String name)throws Exception{Field f=object.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(object);}
    void service(Runnable action)throws Exception{CountDownLatch latch=new CountDownLatch(1);recorderHandler.post(()->{try{action.run();}catch(Throwable e){asyncError=e;}finally{latch.countDown();}});if(!latch.await(5,TimeUnit.SECONDS))throw new IOException("Service handler timeout");if(asyncError!=null)throw new IOException(asyncError);}
    void intent(Intent intent){recorderHandler.post(()->{try{Method handle=JwdService.class.getDeclaredMethod("handle",Intent.class);handle.setAccessible(true);handle.invoke(recorder,intent);}catch(Throwable e){asyncError=e;}});}
    public static final class RecorderHarnessActivity extends JwdActivity {
        @Override public ComponentName startForegroundService(Intent intent){if(intent.getComponent()!=null&&intent.getComponent().getClassName().equals(JwdService.class.getName())){current.intent(intent);return intent.getComponent();}return super.startForegroundService(intent);}
    }
    @Override public Activity newActivity(ClassLoader loader,String name,Intent intent)throws InstantiationException,IllegalAccessException,ClassNotFoundException{return name.equals(JwdActivity.class.getName())?new RecorderHarnessActivity():super.newActivity(loader,name,intent);}
    byte[] wav(int seconds)throws Exception{ByteArrayOutputStream out=new ByteArrayOutputStream();out.write(JwdAudio.wavHeader(seconds*32000));out.write(new byte[seconds*32000]);return out.toByteArray();}
    final class FakeTransport implements JwdTransport {
        final List<String> commands=new CopyOnWriteArrayList<>();String filename="20261102_120000.wav";boolean badCrc,omitTarget;int recordState;
        public void connect(BluetoothDevice d){recorder.ready();}public void probe(BluetoothDevice d){}public void close(){}
        void reply(String text){recorder.command(text.getBytes(StandardCharsets.US_ASCII));}
        public void send(String command){commands.add(command);recorderHandler.post(()->{try{
            if(command.startsWith("APP&SK&"))reply("MCU&SK&OK");
            else if(command.equals("APP&FW"))reply("MCU&FW&fixture");
            else if(command.equals("APP&BAT"))reply("MCU&BAT&80");
            else if(command.equals("APP&SPACE"))reply("MCU&SPA&1000&2000");
            else if(command.equals("APP&RT"))reply(recordState==1?"MCU&RT&"+filename+"&2":"MCU&RT&0");
            else if(command.equals("APP&LIST_DIRS")){reply("MCU&DIRS&20261102");reply("MCU&DIRS_SUM&1");}
            else if(command.equals("APP&LIST&20261102")){if(!omitTarget)reply("MCU&F&20261102&"+filename+"&2");reply("MCU&LIST&"+(omitTarget?0:1));}
            else if(command.equals("APP&STA")){recordState=1;reply("MCU&STA&"+filename);}
            else if(command.equals("APP&STO")){recordState=0;reply("MCU&STO");}
            else if(command.startsWith("APP&U&")){byte[] audio=wav(2);reply("MCU&U&"+audio.length);recorder.audio(audio);java.util.zip.CRC32 crc=new java.util.zip.CRC32();crc.update(audio);reply("MCU&OFF&"+(badCrc?"00000001":String.format(Locale.ROOT,"%08X",crc.getValue())));}
        }catch(Throwable e){asyncError=e;}});}
        int downloads(){int n=0;for(String s:commands)if(s.startsWith("APP&U&"))n++;return n;}
    }
    void recorderFixture()throws Exception{
        recorder=new JwdService();Method attach=ContextWrapper.class.getDeclaredMethod("attachBaseContext",Context.class);attach.setAccessible(true);attach.invoke(recorder,context);ui(recorder::onCreate);
        recorderHandler=(Handler)field(recorder,"handler");transport=new FakeTransport();field(recorder,"ble",transport);
        field(recorder,"address","00:11:22:33:44:55");field(recorder,"deviceName","Fixture recorder");field(recorder,"authorized",true);field(recorder,"connected",true);field(recorder,"recordState",0);JwdService.active=true;
        service(()->{try{Method publish=JwdService.class.getDeclaredMethod("publish");publish.setAccessible(true);publish.invoke(recorder);}catch(Exception e){throw new RuntimeException(e);}});
    }
    String line(InputStream in)throws Exception{ByteArrayOutputStream out=new ByteArrayOutputStream();int n;while((n=in.read())!=-1){if(n==10)break;if(n!=13)out.write(n);}return out.toString("UTF-8");}
    byte[] requestBody(InputStream in,Map<String,String> headers)throws Exception{
        ByteArrayOutputStream out=new ByteArrayOutputStream();if(headers.getOrDefault("transfer-encoding","").equals("chunked")){while(true){String row=line(in);int n=Integer.parseInt(row.split(";",2)[0],16);if(n==0){line(in);break;}byte[] b=in.readNBytes(n);out.write(b);line(in);}}
        else if(headers.containsKey("content-length"))out.write(in.readNBytes(Integer.parseInt(headers.get("content-length"))));return out.toByteArray();
    }
    JSONObject response(String path)throws Exception{
        JSONArray items=new JSONArray();String date="2026-11-02T03:00:00Z";
        if(path.equals("/api/v1/recordings")||path.startsWith("/api/v1/recordings?"))return json("items",items);
        if(path.startsWith("/api/v1/recordings/cloud-")){if(path.endsWith("/transcriptions"))return json("revision",1,"segments",new JSONArray().put(json("id","s1","start_ms",0,"end_ms",2000,"text","Local fixture transcript")));if(path.endsWith("/summaries"))return json("items",new JSONArray().put(json("data",json("title","Test summary","summary","Synthetic loopback result.","key_points",new JSONArray(),"action_items",new JSONArray()))));return json("id",path.substring(path.lastIndexOf('/')+1),"title","Synced recording","status","transcribed","duration_ms",2000,"created_at",date);}
        if(path.startsWith("/api/v1/tasks"))items.put(json("id","personal-task","data",json("title","Review recording sync, local retention and the new task layouts","completed",false,"content","Check the recording on the phone before reviewing the transcript.","due_at",date)));
        if(path.startsWith("/api/v1/teams/visual/tasks")){
            if(path.equals("/api/v1/teams/visual/tasks/task-1"))return json("id","task-1","title_en","Verify the revised recorder workflow and keep the acceptance notes","status","doing","version",1,"assignee_id","member-1","assignee_name","Alex","reviewer_id","member-2","reviewer_name","Sam","description","Verify local saving, interrupted uploads and reconnection.","acceptance_en","A local copy remains available after cloud processing.");
            String state=path.contains("status=")?path.split("status=")[1]:"doing";if(!state.equals("review"))items.put(json("id","task-1","title_en","Verify the revised recorder workflow and keep the acceptance notes","status",state,"assignee_name","Alex"));
        }
        return json("items",items);
    }
    void server()throws Exception{
        server=new ServerSocket(0,16,InetAddress.getByName("127.0.0.1"));Thread accept=new Thread(()->{while(!server.isClosed())try{Socket socket=server.accept();new Thread(()->{try(socket){socket.setSoTimeout(10000);InputStream in=socket.getInputStream();String[] request=line(in).split(" ");Map<String,String> headers=new HashMap<>();String h;while(!(h=line(in)).isEmpty()){int i=h.indexOf(':');headers.put(h.substring(0,i).toLowerCase(Locale.ROOT),h.substring(i+1).trim());}byte[] payload=requestBody(in,headers);int code=200;JSONObject result;
            if(request[0].equals("POST")&&request[1].equals("/api/v1/recordings")){String data=new String(payload,StandardCharsets.ISO_8859_1);java.util.regex.Matcher match=java.util.regex.Pattern.compile("name=\"client_id\"\\r\\n\\r\\n([^\\r]+)").matcher(data);if(!match.find())throw new IOException("Missing client id");String id=match.group(1);uploads.merge(id,1,Integer::sum);if(badRequest.contains(id)){code=400;result=json("code","INVALID_AUDIO","message","Fixture format rejection");}else if(failOnce.remove(id)){code=429;result=json("code","BUSY","message","Fixture retry");}else result=json("recording_id","cloud-"+id,"job_id","job-"+id);}
            else result=response(request[1]);byte[] body=result.toString().getBytes(StandardCharsets.UTF_8);OutputStream out=socket.getOutputStream();out.write(("HTTP/1.1 "+code+" Result\r\nContent-Type: application/json\r\nContent-Length: "+body.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));out.write(body);out.flush();
        }catch(Throwable e){asyncError=e;}}).start();}catch(Exception ignored){}});accept.setDaemon(true);accept.start();
    }
    void filtersGeometry()throws Exception{
        List<TextView> labels=new ArrayList<>();for(String label:new String[]{"All","To accept","In progress","To review"})labels.add(find(team.root,label));
        for(TextView v:labels)check(v!=null&&v.getLineCount()==1&&v.getLayout().getLineWidth(0)<=v.getWidth()-v.getCompoundPaddingLeft()-v.getCompoundPaddingRight()+1,"task_filter_label_fits_"+v.getText());
        for(int i=0;i<labels.size();i++)for(int j=i+1;j<labels.size();j++){View a=labels.get(i),b=labels.get(j);Rect ar=new Rect(a.getLeft(),a.getTop(),a.getRight(),a.getBottom()),br=new Rect(b.getLeft(),b.getTop(),b.getRight(),b.getBottom());check(!Rect.intersects(ar,br),"filters_do_not_overlap_"+i+"_"+j);}
    }
    JSONObject draft(String name)throws Exception{JSONObject d=store.newDraft(name,".wav");Files.write(new File(d.getString("path")).toPath(),wav(2));d.put("duration_ms",2000);store.save(d);created.add(d.getString("id"));return d;}
    void queueChecks()throws Exception{
        store.recordingOptions(true,false,false);JSONObject one=draft("Queue first"),two=draft("Queue second"),three=draft("Queue invalid");String a=one.getString("id"),b=two.getString("id"),c=three.getString("id");failOnce.add(a);badRequest.add(c);
        UploadQueue.enqueue(store,a,true);UploadQueue.enqueue(store,b,true);UploadQueue.enqueue(store,c,true);UploadQueue.enqueue(store,b,true);UploadQueue.resume(context);
        until(()->!UploadQueue.running.get()&&!store.draft(b).optString("recording_id").isEmpty());
        check(uploads.get(a)==1&&uploads.get(b)==1&&uploads.get(c)==1,"queue_drains_multiple_files_without_duplicates");
        check(store.draft(a).optBoolean("upload_requested")&&store.draft(a).optLong("upload_retry_at")>System.currentTimeMillis(),"rate_limit_retries_with_backoff");
        check(!store.draft(c).optBoolean("upload_requested")&&store.draft(c).optString("status").equals("failed"),"bad_file_is_terminal_not_infinite_retry");
        JSONObject retry=store.draft(a);retry.put("upload_retry_at",0);store.save(retry);UploadQueue.resume(context);until(()->!store.draft(a).optString("recording_id").isEmpty());
        check(uploads.get(a)==2,"retry_reuses_original_client_id");check(new File(store.draft(a).getString("path")).isFile()&&new File(store.draft(b).getString("path")).isFile(),"successful_upload_keeps_all_local_files");
        until(()->!UploadQueue.running.get());((JobScheduler)context.getSystemService(Context.JOB_SCHEDULER_SERVICE)).cancel(UploadQueue.JOB_ID);
        JSONObject interrupted=draft("Interrupted upload");String id=interrupted.getString("id");UploadQueue.enqueue(store,id,false);interrupted=store.draft(id);interrupted.put("status","uploading");store.save(interrupted);UploadQueue.resume(context);until(()->!store.draft(id).optString("recording_id").isEmpty());check(uploads.get(id)==1,"persisted_uploading_state_recovers_on_resume");until(()->!UploadQueue.running.get());
        store.recordingOptions(false,false,false);JSONObject recovered=draft("Interrupted recording");String rid=recovered.getString("id");recovered.put("status","recording");store.save(recovered);store.recoverRecordings();check(store.draft(rid).optString("status").equals("local")&&store.draft(rid).optLong("duration_ms")==2000,"interrupted_phone_recording_recovered_locally");
        JSONObject held=draft("Cloud paused");UploadQueue.enqueue(store,held.getString("id"),true);check(!UploadQueue.requested(store,store.draft(held.getString("id")))&&UploadQueue.label(store,store.draft(held.getString("id"))).contains("off"),"cloud_disabled_queue_stays_local_and_allows_manual_upload");JSONObject heldSaved=store.draft(held.getString("id"));heldSaved.put("upload_requested",false);store.save(heldSaved);
        JSONObject other=draft("Scoped queue");UploadQueue.enqueue(store,other.getString("id"),false);String oldScope=store.scope();store.identity("Other fixture","other");check(!UploadQueue.requested(store,other)&&store.drafts().length()==0,"queued_audio_is_account_scoped");store.identity("Flow fixture","flow-"+runName);check(store.scope().equals(oldScope),"original_account_restored");JSONObject clear=store.draft(other.getString("id"));clear.put("upload_requested",false);store.save(clear);
    }
    @Override public void onStart(){boolean ok=false;JSONObject report=new JSONObject();context=getTargetContext();
        try{
            if(!context.getPackageName().equals("com.teno.app.flowverification"))throw new IOException("Isolated application required");
            context.getSharedPreferences("teno",0).edit().remove("jwd.last_address").remove("jwd.last_name").commit();server();store=new Store(context);store.base("http://127.0.0.1:"+server.getLocalPort());store.identity("Flow fixture","flow-"+runName);store.tokens(json("access_token","loopback-flow-fixture"));store.markNativePreferences();store.recordingOptions(false,false,false);
            getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.RECORD_AUDIO);if(Build.VERSION.SDK_INT>=33)getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.POST_NOTIFICATIONS);
            if(Build.VERSION.SDK_INT>=31){getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.BLUETOOTH_CONNECT);getUiAutomation().grantRuntimePermission(context.getPackageName(),Manifest.permission.BLUETOOTH_SCAN);}
            main=(MainActivity)startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready(main);screen("01-library");
            ui(main::actions);ready(main);TextView newTask=find(main.root,"New task"),calendar=find(main.root,"Calendar");int[] a=new int[2],b=new int[2];newTask.getLocationOnScreen(a);calendar.getLocationOnScreen(b);check(a[1]>=b[1]+calendar.getHeight()+main.dp(8),"personal_tasks_actions_have_vertical_spacing");TextView taskTitle=find(main.root,"Review recording sync, local retention and the new task layouts");check(taskTitle!=null&&taskTitle.getLayout().getLineBottom(taskTitle.getLineCount()-1)<=taskTitle.getHeight()-taskTitle.getCompoundPaddingTop()-taskTitle.getCompoundPaddingBottom()+1,"long_task_title_has_full_height");screen("02-personal-tasks");
            click(main.root,"Edit");screen("03-personal-task-edit");ui(()->main.dialog.dismiss());ui(main::home);ready(main);
            JSONObject workspace=json("id","visual","name","Product team","membership",json("id","member-1","role","admin"));team=(TeamActivity)startActivitySync(new Intent(context,TeamActivity.class).putExtra("team",workspace.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready(team);ui(team::teamTasks);ready(team);filtersGeometry();screen("04-team-tasks");
            click(team.root,"To accept");ready(team);check(team.taskFilter.equals("unclaimed")&&find(team.root,"To accept").isSelected(),"accept_filter_selects_requested_status");screen("05-team-accept");click(team.root,"To review");ready(team);check(words(team.root).contains("No tasks in this view."),"empty_task_filter_renders_cleanly");screen("06-team-empty");
            ui(()->team.openTask("task-1"));ready(team);screen("07-team-task-detail");ui(()->team.scroll.fullScroll(View.FOCUS_DOWN));screen("08-team-task-actions");ui(team::finish);team=null;ready(main);
            ui(main::recordPage);until(()->RecorderService.active&&main.page.equals("record"));phoneId=RecorderService.draftId;created.add(phoneId);Thread.sleep(1200);check(RecorderService.capturedBytes>16000,"one_phone_action_captures_pcm_without_setup_page");screen("09-phone-recording");click(main.root,"Stop and save");until(()->!RecorderService.active&&!RecorderService.finishing&&main.page.equals("local_detail"));
            JSONObject saved=store.draft(phoneId);byte[] audio=Files.readAllBytes(new File(saved.getString("path")).toPath());check(ByteBuffer.wrap(audio,40,4).order(ByteOrder.LITTLE_ENDIAN).getInt()==audio.length-44,"stop_finalizes_local_wav_automatically");check(find(main.root,"Keep on phone")==null&&find(main.root,"Save and continue")==null,"local_retention_needs_no_confirmation");check(!uploads.containsKey(phoneId),"cloud_disabled_keeps_audio_local");screen("10-local-recording");
            click(main.root,"Upload and process");until(()->main.page.equals("detail")&&main.currentSummaries.length()>0);check(new File(saved.getString("path")).isFile(),"manual_upload_preserves_local_copy");screen("11-cloud-ready");until(()->!UploadQueue.running.get());
            store.recordingOptions(true,false,false);ui(main::recordPage);until(()->RecorderService.active&&main.page.equals("record"));String automaticPhone=RecorderService.draftId;created.add(automaticPhone);Thread.sleep(1200);click(main.root,"Stop and save");until(()->!store.draft(automaticPhone).optString("recording_id").isEmpty());check(new File(store.draft(automaticPhone).getString("path")).isFile()&&uploads.get(automaticPhone)==1,"phone_stop_automatically_queues_cloud_copy_without_save_dialog");until(()->!UploadQueue.running.get());
            queueChecks();
            recorderFixture();ui(main::home);ready(main);device=(JwdActivity)startActivitySync(new Intent(context,JwdActivity.class).putExtra("start_recording",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));until(()->new JSONObject(JwdService.snapshot).optInt("record_state")==1);
            check(transport.commands.contains("APP&STA")&&!RecorderService.active,"primary_device_entry_starts_hardware_without_phone_fallback");Thread.sleep(900);screen("12-recorder-recording");click(device.getWindow().getDecorView(),"Stop and save");until(()->!new JSONObject(JwdService.snapshot).optString("last_draft").isEmpty());
            String did=new JSONObject(JwdService.snapshot).getString("last_draft");created.add(did);JSONObject deviceDraft=store.draft(did);check(new File(deviceDraft.getString("path")).length()==64044&&deviceDraft.optString("jwd_verification").equals("crc32_verified"),"stop_syncs_matching_verified_file_without_manual_selection");check(!uploads.containsKey(did),"device_local_save_respects_cloud_setting");Thread.sleep(1100);screen("13-recorder-saved");int downloads=transport.downloads();intent(new Intent().setAction("sync"));Thread.sleep(800);check(transport.downloads()==downloads,"repeated_sync_skips_verified_device_file");
            store.recordingOptions(true,false,false);transport.filename="20261102_121000.wav";service(()->{transport.recordState=1;transport.reply("MCU&AUTO&STA&"+transport.filename);transport.recordState=0;transport.reply("MCU&AUTO&STO");});until(()->transport.downloads()>downloads&&!new JSONObject(JwdService.snapshot).optString("last_draft").isEmpty());String hardwareId=new JSONObject(JwdService.snapshot).optString("last_draft");created.add(hardwareId);check(!hardwareId.equals(did),"hardware_button_recording_uses_same_auto_sync_flow");until(()->!store.draft(hardwareId).optString("recording_id").isEmpty());check(new File(store.draft(hardwareId).getString("path")).isFile()&&uploads.get(hardwareId)==1,"hardware_auto_sync_upload_keeps_local_copy");until(()->!UploadQueue.running.get());
            transport.filename="20261102_122000.wav";transport.badCrc=true;int before=store.drafts().length();service(()->{transport.recordState=1;transport.reply("MCU&AUTO&STA&"+transport.filename);transport.recordState=0;transport.reply("MCU&AUTO&STO");});until(()->!new JSONObject(JwdService.snapshot).optBoolean("authorized"));check(store.drafts().length()==before&&!store.deviceRecordSynced("00:11:22:33:44:55","20261102",transport.filename,2),"bad_crc_creates_no_local_draft_or_sync_ledger");
            transport.badCrc=false;transport.filename="20261102_123000.wav";transport.omitTarget=true;
            store.deviceKey("00:11:22:33:44:55","FixtureKey123456");store.pendingDeviceRecord("00:11:22:33:44:55",transport.filename);
            int starts=Collections.frequency(transport.commands,"APP&STA");service(recorder::ready);
            until(()->new JSONObject(JwdService.snapshot).optString("sync_error").contains("not available yet"));
            check(Collections.frequency(transport.commands,"APP&STA")==starts,"reconnect_never_starts_an_unrequested_recording");
            check(store.recorderAddress().equals("00:11:22:33:44:55")&&store.deviceKey(store.recorderAddress()).equals("FixtureKey123456"),"successful_authorization_remembers_recorder_and_keeps_key");
            check(new JSONObject(JwdService.snapshot).optString("last_draft").isEmpty(),"missing_expected_file_never_opens_an_unrelated_recording");
            transport.omitTarget=false;intent(new Intent().setAction("sync"));until(()->!new JSONObject(JwdService.snapshot).optString("last_draft").isEmpty());String resumed=new JSONObject(JwdService.snapshot).optString("last_draft");created.add(resumed);
            check(store.draft(resumed).optString("jwd_file").equals(transport.filename),"retry_sync_recovers_original_saved_file");until(()->!UploadQueue.running.get());
            ok=true;
        }catch(Throwable e){try{report.put("failure",e.toString());}catch(Exception ignored){}}
        finally{
            try{if(RecorderService.active)context.startService(new Intent(context,RecorderService.class).setAction("stop"));if(device!=null)ui(device::finish);if(recorder!=null){ui(recorder::onDestroy);Thread.sleep(200);}if(team!=null)ui(team::finish);if(main!=null)ui(main::finish);until(()->!UploadQueue.running.get());((JobScheduler)context.getSystemService(Context.JOB_SCHEDULER_SERVICE)).cancel(UploadQueue.JOB_ID);for(String id:created)try{store.deleteDraft(store.draft(id));}catch(Exception ignored){}if(server!=null)server.close();}catch(Exception ignored){}
            JwdService.active=false;JwdService.snapshot="{}";
            try{report.put("all_passed",ok).put("checks",checks).put("screens",screens).put("scope","API 35 emulator; actual PCM capture and loopback HTTP uploads; synthetic BLE transport replies. No physical recorder, Azure or production backend calls.");Files.write(new File(context.getFilesDir(),runName+"-flow-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle result=new Bundle();result.putString("stream",report.toString());finish(ok?Activity.RESULT_OK:Activity.RESULT_CANCELED,result);
        }
    }
}
