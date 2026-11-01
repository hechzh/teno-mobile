package com.teno.app;

import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.media.*;
import android.os.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;

/** Explicit verification using synthetic source audio. Does not claim a physical BLE test. */
public final class JwdInstrumentation extends Instrumentation {
    final JSONArray checks=new JSONArray();final JSONObject report=new JSONObject();
    void check(boolean ok,String name)throws Exception{if(!ok)throw new IOException(name);checks.put(new JSONObject().put("check",name).put("passed",true));Bundle b=new Bundle();b.putString("stream","PASS "+name+"\n");sendStatus(0,b);}
    @Override public void onCreate(Bundle args){super.onCreate(args);start();}
    @Override public void onStart(){
        Context c=getTargetContext();Store store=new Store(c);boolean success=false;JwdActivity activity=null;
        try{
            JSONObject account=new JSONObject(new String(Files.readAllBytes(new File(c.getFilesDir(),"private-test.json").toPath()),StandardCharsets.UTF_8));
            Api api=new Api(store);check(api.get("/health/ready").optString("status").equals("ready"),"public_https_ready");api.login(account.getString("username"),account.getString("password"));check(!store.scope().isEmpty(),"authenticated_account_scope");
            String key=JwdProtocol.newKey();store.deviceKey("00:11:22:33:44:55",key);check(new Store(c).deviceKey("00:11:22:33:44:55").equals(key),"device_key_keystore_round_trip");
            String encrypted=c.getSharedPreferences("teno",0).getString("jwd.key.00:11:22:33:44:55","");check(!encrypted.contains(key),"device_key_not_stored_as_plaintext");
            File fixture=new File(c.getFilesDir(),"jwd-synthetic.raw"),received=new File(store.folder(),"jwd-test.raw");byte[] source=Files.readAllBytes(fixture.toPath());
            check(source.length>8000&&source.length%80==0,"synthetic_opus80_fixture_intact");
            String crc=JwdProtocol.crcFile(fixture);
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(received,source.length)){
                // Simulate the different-sized GATT notifications, including OFF before the final data.
                int at=0;while(at<source.length){int n=Math.min(244,source.length-at);if(at+n==source.length)r.end(crc);byte[] b=new byte[n];System.arraycopy(source,at,b,0,n);r.write(b);at+=n;}
                check(r.finish().equals("crc32_verified"),"fragmented_transfer_and_crc_gate");
            }
            JSONObject draft=JwdAudio.importVerified(store,received,"TEST-SYNTHETIC","2026-10-31","Teno-JWD-合成验收",0,"crc32_verified",p->{});
            draft.put("language","en-US").put("title","Teno JWD 专用解码与上传验收（合成音频）");store.save(draft);
            File wav=new File(draft.getString("path"));long expected=source.length/80*640+44;
            check(wav.length()==expected,"vendor_native_decoder_all_frames_to_wav");
            check(draft.getLong("duration_ms")>1000,"decoded_wav_has_duration");
            JSONObject same=JwdAudio.importVerified(store,received,"TEST-SYNTHETIC","2026-10-31","Teno-JWD-合成验收",0,"crc32_verified",p->{});
            check(draft.getString("id").equals(same.getString("id")),"same_device_file_reuses_client_id");
            File bad=new File(store.folder(),"bad-opus.raw");byte[] corrupt=source.clone();corrupt[80]=0;Files.write(bad.toPath(),corrupt);File invalid=new File(store.folder(),"bad-opus.wav");boolean rejected=false;
            try{JwdAudio.decode(bad,invalid,p->{});}catch(IOException expectedError){rejected=true;}check(rejected&&!invalid.exists(),"invalid_opus_frame_never_silently_skipped");bad.delete();
            Files.copy(wav.toPath(),new File(c.getFilesDir(),"jwd-decoded.wav").toPath(),StandardCopyOption.REPLACE_EXISTING);
            activity=(JwdActivity)startActivitySync(new Intent(c,JwdActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));Thread.sleep(1000);
            try(FileOutputStream out=new FileOutputStream(new File(c.getFilesDir(),"jwd-test-screen.png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}check(!JwdService.active,"hardware_screen_does_not_fake_connection");
            MediaPlayer player=new MediaPlayer();try{player.setDataSource(wav.getAbsolutePath());player.prepare();player.start();Thread.sleep(500);check(player.getCurrentPosition()>0,"decoded_file_local_playback");}finally{player.release();}
            String id=draft.getString("id");runOnMainSync(()->c.startForegroundService(new Intent(c,TransferService.class).putExtra("id",id)));
            Thread.sleep(1000);for(int i=0;i<90&&TransferService.active;i++)Thread.sleep(1000);
            draft=store.draft(id);String rid=draft.optString("recording_id");check(!rid.isEmpty(),"verified_device_draft_real_upload_service");report.put("recording_id",rid);
            boolean transcribed=false;String transcript="";
            for(int i=0;i<100;i++){JSONObject job=api.get("/api/v1/jobs/"+draft.getString("job_id"));if(job.optString("status").equals("failed"))throw new IOException("transcription_job_failed");if(job.optString("status").equals("completed")){JSONObject t=api.get("/api/v1/recordings/"+rid+"/transcriptions");JSONArray segments=t.optJSONArray("segments");transcribed=segments!=null&&segments.length()>0;if(transcribed)transcript=segments.toString();break;}Thread.sleep(2000);}
            check(transcribed,"native_decoded_fixture_azure_transcription");report.put("transcript",transcript);
            JSONObject result=api.upload("/api/v1/recordings",wav,wav.getName(),new JSONObject().put("client_id",id).put("title",draft.getString("title")).put("language","en-US"),null);
            check(result.optString("recording_id").equals(rid),"upload_retry_is_idempotent");
            report.put("duration_ms",draft.getLong("duration_ms")).put("raw_bytes",source.length).put("wav_bytes",wav.length()).put("crc32",crc);success=true;
        }catch(Throwable e){try{report.put("failure",e.getClass().getSimpleName()+": "+e.getMessage());}catch(Exception ignored){}}
        finally{
            if(activity!=null){JwdActivity current=activity;runOnMainSync(current::finish);}
            new File(c.getFilesDir(),"private-test.json").delete();
            try{report.put("checks",checks).put("all_passed",success).put("android_api",Build.VERSION.SDK_INT).put("evidence_scope","Synthetic fixed-80-byte Opus fixture; Android emulator with ARM translation; real HTTPS upload and ASR. Physical JWD BLE and Magic4 Pro remain untested.");Files.write(new File(c.getFilesDir(),"jwd-acceptance-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle b=new Bundle();b.putString("stream",report.toString());finish(success?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);
        }
    }
}
