package com.teno.app;
import android.content.Context;
import org.json.JSONObject;
import java.io.File;
import java.nio.file.Files;

/** Synthetic account only; verifies durable choices, never invokes a supplier. */
final class Processing082Checks {
    static void run(RuntimeInstrumentation test, Context context)throws Exception {
        Store store=new Store(context);
        if(!store.scope().isEmpty()&&!context.getSharedPreferences("teno",0).getBoolean("runtime_test_fixture",false))throw new IllegalStateException("Fixture required");
        store.identity("Processing fixture","processing-082");
        UiLocale.set(context,"zh");
        JSONObject draft=store.newDraft("语言测试",".txt").put("kind","file");
        Files.write(new File(draft.getString("path")).toPath(),"Synthetic text".getBytes(java.nio.charset.StandardCharsets.UTF_8));
        store.freezeGeneration(draft);store.save(draft);
        test.check(draft.getString("output_language").equals("zh-CN"),"Chinese_UI_freezes_Chinese_output");
        UiLocale.set(context,"en");store.freezeGeneration(draft);
        test.check(draft.getString("output_language").equals("zh-CN"),"queued_language_survives_UI_change");
        Store restart=new Store(context);JSONObject restored=restart.draft(draft.getString("id"));restart.freezeGeneration(restored);
        test.check(restored.getString("output_language").equals("zh-CN"),"restart_and_retry_preserve_language");
        JSONObject next=store.newDraft("Next file",".txt");store.freezeGeneration(next);
        test.check(next.getString("output_language").equals("en-US"),"next_file_uses_English_interface");
        JSONObject explicit=store.newDraft("Override",".txt");
        store.generationOptions(explicit,new JSONObject().put("output_language","zh-CN").put("output_language_origin","override"));store.freezeGeneration(explicit);
        test.check(explicit.getString("output_language").equals("zh-CN"),"single_file_override_is_frozen");
        JSONObject following=store.newDraft("Following",".txt");store.freezeGeneration(following);
        test.check(following.getString("output_language").equals("en-US"),"override_does_not_leak_to_next_file");
        store.recordingOptions(false,false);draft.put("upload_requested",true).put("upload_automatic",true).put("status","queued");
        JSONObject state=UploadQueue.presentation(store,draft,UploadQueue.networkAvailable(context));
        test.check(state.getString("stage").equals("saved")&&state.getString("stage_status").equals("idle")&&state.getString("waiting_reason").equals("cloud_disabled"),"cloud_disabled_is_local_only_not_processing");
        draft.put("recording_id","synthetic-cloud-id").put("processing",new JSONObject().put("stage","generating_note").put("stage_status","failed").put("preserved",new JSONObject().put("transcript",true).put("notes",1)));
        state=UploadQueue.presentation(store,draft,UploadQueue.networkAvailable(context));
        test.check(state.getString("stage_status").equals("failed")&&state.getJSONObject("preserved").getBoolean("local_file"),"latest_note_failure_retains_local_and_old_artifacts");
        UiLocale.set(context,"system");
    }
}
