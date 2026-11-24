package com.teno.app;

import android.os.Handler;
import org.json.JSONObject;
import java.util.*;

/** Compile these fixtures with JwdProtocol, RecorderOwnership and org.json on the JVM. */
public final class RecorderPairingHostTest implements RecorderOwnership.Port, AutoCloseable {
    static final String MAC = "A00102030405", OTHER = "A00607080910", RADIO = "radio-fixture";
    static final String KEY = "FixtureAccount01", OLD = "FixtureLegacy001";
    final Store store = new Store();
    final Handler handler = new Handler();
    final RecorderOwnership ownership = new RecorderOwnership(store, handler, this);
    String sent = "";
    int reads, readyCount, inventoryCount, reconnects;

    static void check(boolean ok, String name) {
        if (!ok) throw new AssertionError(name);
        System.out.println("PASS " + name);
    }
    void dispatch(int count) throws Exception { for (int i=0; i<count; i++) handler.dispatch(); }
    public void sendKey(String key) { sent=key; }
    public void verifyIdentity() { reads++; }
    public void ready() { readyCount++; }
    public void inventory() { inventoryCount++; }
    public void reconnect() { reconnects++; }
    public void seek() {}
    public void unbind() {}
    public void changed() {}
    public void close(String message) {}
    public void close() { ownership.dispose(); }

    void fresh() throws Exception { ownership.authorizeDaily(RADIO,"Fixture card",""); dispatch(1); }
    public static void main(String[] args) throws Exception {
        try (var t=new RecorderPairingHostTest()) {
            t.store.selected=OTHER;
            t.fresh();
            check(t.sent.equals(KEY)&&t.store.posts.equals(List.of("connection-key"))&&t.store.body.isEmpty(),"daily_first_write_is_fixed_account_key_without_identity");
            check(t.readyCount==0&&t.ownership.blocked()&&t.store.key.isEmpty(),"credential_is_volatile_until_firmware_acknowledges");
            t.ownership.accepted();
            check(t.reads==0&&t.readyCount==1&&!t.ownership.blocked()&&t.ownership.state.equals("authorized"),"ack_enables_daily_recording_and_sync_without_mac");
            check(t.store.key.equals(KEY)&&t.store.posts.size()==1&&t.store.recorded.isEmpty()&&t.ownership.hardware().isEmpty(),"no_background_identity_lookup_or_cloud_registration");
            t.ownership.accepted();check(t.readyCount==1,"duplicate_ack_is_ignored");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.fresh();t.ownership.rejected();
            check(t.readyCount==0&&t.store.key.isEmpty()&&t.ownership.blocked()&&t.store.posts.size()==1,"rejected_key_never_claims_or_opens_files");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.key=OLD;t.fresh();
            check(t.sent.equals(OLD)&&t.store.body.optString("original_key").equals(OLD),"same_account_cached_legacy_key_is_checked_by_server");
            t.ownership.accepted();check(t.reads==0&&t.readyCount==1&&t.store.key.equals(OLD),"legacy_key_remains_valid_without_mac");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.key=KEY;
            t.ownership.authorizeDaily(RADIO,"Fixture card",OLD);t.dispatch(1);
            check(t.sent.equals(OLD)&&t.store.body.optString("original_key").equals(OLD)&&t.store.key.equals(KEY),"manual_original_key_is_not_saved_before_ack");
            t.ownership.rejected();check(t.store.key.equals(KEY)&&t.readyCount==0,"rejected_manual_key_preserves_last_successful_key");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.key=KEY;t.ownership.authorizeDaily(RADIO,"Fixture card",OLD);t.dispatch(1);t.ownership.accepted();
            check(t.store.key.equals(OLD)&&t.readyCount==1,"accepted_manual_key_is_saved_after_ack");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.recorded=t.store.recorder();t.store.state="owned";t.ownership.authorizeDaily(RADIO,"Fixture card","");t.dispatch(2);
            check(t.sent.equals(OLD)&&t.store.posts.equals(List.of("resolve","restore")),"known_cloud_recorder_restores_only_its_own_key");
            t.ownership.accepted();check(t.reads==0&&t.readyCount==1&&t.ownership.state.equals("owned")&&t.ownership.hardware().isEmpty(),"known_cloud_recorder_needs_no_new_radio_identity_read");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.recorded=t.store.recorder();t.store.key=OLD;t.store.state="transfer_required";t.fresh();
            check(t.sent.isEmpty()&&t.readyCount==0,"server_foreign_owner_denial_sends_no_key");
            t.store.offline=true;t.fresh();check(t.sent.isEmpty()&&t.readyCount==0,"offline_reconnect_cannot_bypass_known_ownership_denial");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.key=OLD;t.store.lastAddress=RADIO;t.store.deny=true;t.fresh();check(t.sent.isEmpty()&&t.readyCount==0,"connection_key_conflict_never_uses_local_key");
            t.store.deny=false;t.store.offline=true;t.fresh();check(t.sent.isEmpty(),"known_pending_operation_survives_offline_retry");
            t.store.offline=false;t.fresh();t.ownership.disconnected();t.sent="";t.store.offline=true;t.fresh();
            check(t.sent.isEmpty(),"online_permission_without_ack_does_not_restore_offline_access");
            t.store.offline=false;t.fresh();t.ownership.accepted();t.sent="";t.store.offline=true;t.fresh();
            check(t.sent.equals(OLD),"online_permission_and_ack_restore_offline_access");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.offline=true;t.fresh();check(t.sent.isEmpty()&&t.readyCount==0,"offline_new_card_stays_closed");
            t.store.key=OLD;t.fresh();check(t.sent.isEmpty(),"unverified_saved_key_alone_does_not_enable_offline");
            t.store.lastAddress=RADIO;t.ownership.authorizeDaily(RADIO,"Fixture card",KEY);t.dispatch(1);check(t.sent.isEmpty(),"unconfirmed_manual_key_cannot_run_offline");
            t.fresh();t.ownership.accepted();check(t.sent.equals(OLD)&&t.readyCount==1&&t.reads==0,"offline_existing_account_recorder_uses_its_saved_key");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.fresh();t.ownership.disconnected();t.ownership.accepted();
            check(t.readyCount==0&&t.store.key.isEmpty(),"late_ack_after_disconnect_cannot_authorize");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.fresh();t.store.account="another-account";t.ownership.accepted();
            check(t.readyCount==0&&t.store.key.isEmpty(),"account_switch_fences_firmware_ack");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.secure("jwd.operation."+t.store.scope(),"fixture");
            boolean refused=false;try{t.fresh();}catch(java.io.IOException e){refused=true;}
            check(refused&&t.sent.isEmpty()&&t.store.posts.isEmpty(),"local_pending_operation_blocks_ordinary_connection");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.ownership.authorizeDaily(RADIO,"Fixture card","");t.ownership.cancel();
            Thread.sleep(40);check(t.sent.isEmpty()&&!t.ownership.authorizingDaily(),"cancel_invalidates_pending_connection_key_request");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.fresh();t.ownership.accepted();
            t.ownership.identity(MAC,RADIO,"Fixture card",true);t.dispatch(1);
            check(t.ownership.state.equals("claim_required")&&!t.store.posts.contains("claim"),"explicit_registration_requires_a_real_identity_and_confirmation");
            t.ownership.claim("",true);t.dispatch(2);t.ownership.identity(MAC,RADIO,"Fixture card",true);t.ownership.accepted();t.dispatch(1);
            check(t.store.posts.equals(List.of("connection-key","resolve","claim","start","complete"))&&t.ownership.state.equals("owned")&&t.store.recorded.optString("hardware_id").equals(MAC),"explicit_claim_records_only_verified_hardware_id");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.kind="release";t.ownership.start("operation");t.dispatch(1);
            boolean refused=false;
            try{t.ownership.compatibility(RADIO,"Fixture card","");}catch(java.io.IOException e){refused=true;}
            check(refused&&t.sent.isEmpty(),"unproven_radio_never_receives_operation_key");
            t.store.recorded=t.store.recorder();
            t.ownership.compatibility(RADIO,"Fixture card","");t.ownership.accepted();
            check(t.sent.equals(OLD)&&t.reads==1&&t.inventoryCount==0,"release_keeps_operation_key_and_waits_for_actual_mac");
            t.ownership.confirmIdentity(MAC);
            check(t.inventoryCount==1 && !t.store.posts.contains("complete"), "verified_release_resumes_existing_inventory");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.kind="release";t.store.stage="new_key_accepted";t.ownership.start("operation");t.dispatch(1);
            t.ownership.compatibility(RADIO,"Fixture card",MAC);t.ownership.accepted();t.ownership.confirmIdentity(MAC);
            check(t.sent.equals(KEY)&&t.reconnects==1,"resume_proves_current_key_and_mac_before_testing_old_key");
            t.ownership.operationAuthorization();check(t.sent.equals(OLD),"reject_old_step_preserved");
        }
    }
}

class Store {
    String selected="", key="", stage="", kind="claim", state="claim_required", startedKey=RecorderPairingHostTest.KEY;
    JSONObject recorded=new JSONObject(),body=new JSONObject();
    String lastAddress="";String recorderAddress(){return lastAddress;}
    String account="test-account";boolean deny,offline;
    List<String> posts=new ArrayList<>();
    Map<String,String> secrets=new HashMap<>();
    String scope(){return account;}
    String token(String type){return "test-session";}
    String secure(String name){return secrets.getOrDefault(name,"");}
    void secure(String name,String value){secrets.put(name,value);}
    String selectedRecorder(){return selected;}
    void selectRecorder(String id){selected=id;}
    String deviceKey(String address){return key;}
    void deviceKey(String address,String value){key=value;}
    JSONObject recorderIdentity(String address){return recorded;}
    void recorderIdentity(String address,JSONObject value){recorded=value;}
    void rememberRecorder(String address,String name){lastAddress=address;}
    void forgetRecorder(String address){}
    JSONObject recorder(){return new JSONObject().put("id","recorder").put("hardware_id",RecorderPairingHostTest.MAC);}
}
class JwdService {static boolean accountClosing;}
class Api {
    static class Failure extends java.io.IOException { final int status=409;final String code="RECORDER_OPERATION_PENDING"; }
    final Store store;
    Api(Store store){this.store=store;}
    Api(Store store,int connectMs,int readMs){this(store);}
    JSONObject get(String path){throw new AssertionError(path);}
    JSONObject post(String path,JSONObject body)throws java.io.IOException{
        String route=path.substring(path.lastIndexOf('/')+1);store.posts.add(route);store.body=body;
        if(store.deny)throw new Failure();
        if(store.offline)throw new java.net.ConnectException("Offline");
        JSONObject op=new JSONObject().put("id","operation").put("kind",store.kind).put("recorder",store.recorder());
        return switch(route){
            case "connection-key" -> {
                if (body.has("confirm")||body.has("hardware_id")||body.length()>1)throw new AssertionError("Unverified identity in account request");
                yield new JSONObject().put("device_key",body.optString("original_key",RecorderPairingHostTest.KEY));
            }
            case "resolve" -> new JSONObject().put("state",store.state).put("recorder",store.recorder());
            case "restore" -> store.recorder().put("device_key",RecorderPairingHostTest.OLD);
            case "claim" -> {
                if(!body.getBoolean("confirm_card_recordings")||!body.optString("original_key").equals(store.key)||!body.getString("hardware_id").equals(RecorderPairingHostTest.MAC))throw new AssertionError("Invalid claim proof");
                yield op;
            }
            case "start" -> op.put("device_key",store.startedKey).put("previous_key",RecorderPairingHostTest.OLD)
                    .put("checkpoint",new JSONObject().put("stage",store.stage));
            case "complete" -> {if(!body.getBoolean("new_key_accepted"))throw new AssertionError("Missing proof");yield op;}
            default -> throw new AssertionError(route);
        };
    }
}
