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

    void fresh() throws Exception { ownership.compatibility(RADIO,"Fixture card",""); dispatch(1); }
    public static void main(String[] args) throws Exception {
        try (var t=new RecorderPairingHostTest()) {
            t.store.selected=OTHER; // A previous selection cannot identify a new physical card.
            t.fresh();
            check(t.sent.equals(KEY) && t.store.posts.equals(List.of("pairing-key")), "only_account_key_before_protocol_identity");
            t.ownership.accepted();
            check(t.reads==1 && t.readyCount==0 && t.store.key.isEmpty(), "ack_alone_never_grants_file_access");
            t.ownership.confirmIdentity(MAC); t.dispatch(4);
            check(t.store.posts.equals(List.of("pairing-key","resolve","claim","start","complete")) && t.readyCount==1, "fresh_claim_after_verified_id");
            check(t.store.key.equals(KEY) && t.store.recorded.optString("hardware_id").equals(MAC), "save_verified_protocol_identity_and_key");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.fresh();t.ownership.rejected();
            check(t.store.posts.equals(List.of("pairing-key")) && t.store.key.isEmpty() && t.readyCount==0, "rejected_key_never_claims_or_opens_files");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.fresh();t.ownership.accepted();t.ownership.disconnected();
            check(!t.ownership.pairing() && t.store.posts.size()==1 && t.readyCount==0, "disconnect_before_identity_leaves_no_claim");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.state="transfer_required";t.fresh();t.ownership.accepted();t.ownership.confirmIdentity(MAC);t.dispatch(1);
            check(!t.store.posts.contains("claim") && t.readyCount==0, "foreign_owner_denied_after_firmware_ack");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.selected=MAC;t.store.state="owned";
            t.ownership.compatibility(RADIO,"Fixture card",MAC);t.dispatch(2);
            check(t.sent.equals(OLD) && t.store.key.isEmpty(), "explicit_cloud_selection_restores_only_owned_key");
            t.ownership.accepted();t.ownership.confirmIdentity(OTHER);
            check(t.readyCount==0 && t.store.key.isEmpty() && !t.ownership.pairing(), "different_protocol_mac_never_accepted");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.recorded=t.store.recorder();t.store.state="owned";
            t.ownership.compatibility(RADIO,"Fixture card","");t.dispatch(2);
            t.ownership.accepted();t.ownership.confirmIdentity(MAC);t.dispatch(2);
            check(t.store.key.equals(OLD)&&t.readyCount==1&&!t.store.posts.contains("claim"), "known_legacy_recorder_keeps_its_original_key");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.store.startedKey=OLD;t.fresh();t.ownership.accepted();t.ownership.confirmIdentity(MAC);t.dispatch(3);
            check(!t.store.posts.contains("complete")&&t.store.key.isEmpty()&&t.readyCount==0,"changed_claim_key_cannot_complete");
        }
        try (var t=new RecorderPairingHostTest()) {
            t.ownership.compatibility(RADIO,"Fixture card","");t.ownership.cancel();
            // Whether the cancelled HTTP call started or not, no key may reach the card.
            Thread.sleep(40);check(t.sent.isEmpty()&&!t.ownership.pairing(),"cancel_clears_pending_pairing");
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
    JSONObject recorded=new JSONObject();
    List<String> posts=new ArrayList<>();
    Map<String,String> secrets=new HashMap<>();
    String scope(){return "test-account";}
    String token(String type){return "test-session";}
    String secure(String name){return secrets.getOrDefault(name,"");}
    void secure(String name,String value){secrets.put(name,value);}
    String selectedRecorder(){return selected;}
    void selectRecorder(String id){selected=id;}
    String deviceKey(String address){return key;}
    void deviceKey(String address,String value){key=value;}
    JSONObject recorderIdentity(String address){return recorded;}
    void recorderIdentity(String address,JSONObject value){recorded=value;}
    void rememberRecorder(String address,String name){}
    void forgetRecorder(String address){}
    JSONObject recorder(){return new JSONObject().put("id","recorder").put("hardware_id",RecorderPairingHostTest.MAC);}
}
class JwdService {static boolean accountClosing;}
class Api {
    static class Failure extends Exception {}
    final Store store;
    Api(Store store){this.store=store;}
    JSONObject get(String path){throw new AssertionError(path);}
    JSONObject post(String path,JSONObject body){
        String route=path.substring(path.lastIndexOf('/')+1);store.posts.add(route);
        JSONObject op=new JSONObject().put("id","operation").put("kind",store.kind).put("recorder",store.recorder());
        return switch(route){
            case "pairing-key" -> {
                if (!body.getBoolean("confirm") || body.has("hardware_id"))throw new AssertionError("Unverified address supplied as identity");
                yield new JSONObject().put("device_key",RecorderPairingHostTest.KEY);
            }
            case "resolve" -> new JSONObject().put("state",store.state).put("recorder",store.recorder());
            case "restore" -> store.recorder().put("device_key",RecorderPairingHostTest.OLD);
            case "claim" -> {
                if(!body.getBoolean("account_key_only")||body.has("original_key")||!body.getString("hardware_id").equals(RecorderPairingHostTest.MAC))throw new AssertionError("Invalid claim proof");
                yield op;
            }
            case "start" -> op.put("device_key",store.startedKey).put("previous_key",RecorderPairingHostTest.OLD)
                    .put("checkpoint",new JSONObject().put("stage",store.stage));
            case "complete" -> {if(!body.getBoolean("new_key_accepted"))throw new AssertionError("Missing proof");yield op;}
            default -> throw new AssertionError(route);
        };
    }
}
