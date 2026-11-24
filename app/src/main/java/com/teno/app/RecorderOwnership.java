package com.teno.app;

import android.os.Handler;
import org.json.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;

/** Owns authorization transitions; no UI or ordinary connect path can send a new key. */
final class RecorderOwnership {
    interface Port {
        void sendKey(String key); void verifyIdentity(); void reconnect(); void inventory(); void unbind();
        void ready(); void changed(); void close(String message); void seek();
    }
    private final Store store; private final Handler handler; private final Port port;
    private final ExecutorService network=Executors.newSingleThreadExecutor();
    private JSONObject operation=new JSONObject(), recorder=new JSONObject();
    private String owner="",address="",name="",hardware="",stage="",auth="",before="";
    private volatile long generation;
    private boolean running,requesting;
    private String rejectedClaimHardware="";
    private boolean compatibility;
    private String pairingKey="",expectedIdentity="";
    private String operationDevice="",operationTicket="",operationOwner="";
    private boolean operationIdentityRead,operationProof;
    String state="disconnected",message="";
    RecorderOwnership(Store store,Handler handler,Port port){this.store=store;this.handler=handler;this.port=port;owner=store.scope();
        try{String saved=store.secure(journal());if(!saved.isEmpty()){operation=new JSONObject(saved);recorder=operation.optJSONObject("recorder");if(recorder==null)recorder=new JSONObject();state="recovery_required";message="Continue the pending recorder operation.";}}catch(Exception ignored){}
    }
    static String canonical(String value)throws IOException{
        String result=value.replace(":","").replace("-","").toUpperCase(Locale.ROOT);
        if(!result.matches("[0-9A-F]{12}")||result.equals("000000000000")||result.equals("FFFFFFFFFFFF"))throw new IOException("Recorder identity could not be verified.");return result;
    }
    static String inventoryHash(List<String> entries)throws Exception{
        ArrayList<String> sorted=new ArrayList<>(entries);Collections.sort(sorted);
        byte[] bytes=MessageDigest.getInstance("SHA-256").digest(String.join("\n",sorted).getBytes(StandardCharsets.UTF_8));
        StringBuilder value=new StringBuilder();for(byte b:bytes)value.append(String.format(Locale.ROOT,"%02x",b&255));return value.toString();
    }
    JSONObject view(){JSONObject value=new JSONObject();try{value.put("state",state).put("message",message).put("hardware_id",hardware).put("recorder",recorder)
        .put("operation_id",operation.optString("id")).put("stage",stage).put("busy",requesting||running).put("claim_required",state.equals("claim_required"));}catch(Exception ignored){}return value;}
    boolean blocked(){return running||requesting||!state.equals("owned")&&!state.equals("offline_owned");}
    boolean changing(){return running||compatibility;}
    boolean pairing(){return compatibility;}
    boolean pendingOperation(){return running&&!compatibility;}
    String hardware(){return hardware;}
    private void clearPairing(){compatibility=false;pairingKey="";expectedIdentity="";}
    private void clearOperationDevice(){operationDevice="";operationTicket="";operationOwner="";operationProof=false;operationIdentityRead=false;}
    void cancel(){clearOperationDevice();clearPairing();generation++;running=false;requesting=false;auth="";state="disconnected";}
    void connectionAttempt(){clearPairing();generation++;requesting=false;auth="";if(!running){hardware="";state="disconnected";}}
    void dispose(){cancel();network.shutdownNow();}
    private void update(String state,String message){this.state=state;this.message=message;port.changed();}
    private String journal(){return "jwd.operation."+owner;}
    private void persist()throws Exception{operation.put("local_stage",stage).put("files_before",before);store.secure(journal(),operation.toString());}
    void fail(String text){boolean pairing=compatibility;clearOperationDevice();clearPairing();generation++;running=false;requesting=false;auth="";update(pairing?"pairing_failed":"recovery_required",text);port.close(text);}
    interface Done{void accept(JSONObject value)throws Exception;}
    private void api(String path,JSONObject body,Done done,Done offline){
        long ticket=++generation;String scope=store.scope();requesting=true;port.changed();
        network.execute(()->{JSONObject value=null;Exception failure=null;
            if(ticket!=generation||!scope.equals(store.scope())||JwdService.accountClosing)return;
            try{Api api=new Api(store);value=body==null?api.get(path):api.post(path,body);}catch(Exception e){failure=e;}
            JSONObject result=value;Exception error=failure;handler.post(()->{
                if(ticket!=generation||!scope.equals(store.scope())||store.token("access_token").isEmpty()||JwdService.accountClosing)return;
                requesting=false;
                try{if(error==null)done.accept(result);else if(offline!=null&&!(error instanceof Api.Failure))offline.accept(new JSONObject());else fail(error.getMessage());}
                catch(Exception e){fail(e.getMessage());}
            });
        });
    }
    void compatibility(String address,String name,String selected)throws Exception{
        if(requesting||compatibility)throw new IOException("Wait for the current recorder request.");
        if(running){
            String target=canonical(operation.getJSONObject("recorder").getString("hardware_id"));
            String cached=store.recorderIdentity(address).optString("hardware_id");
            if(!cached.isEmpty()&&!target.equals(canonical(cached)))throw new IOException("Recorder identity could not be verified.");
            boolean chosen=selected!=null&&!selected.isEmpty()&&target.equals(canonical(selected))&&target.equals(store.selectedRecorder());
            if(cached.isEmpty()&&!chosen&&!address.equals(operation.optString("verified_radio")))
                throw new IOException("Select the registered recorder for this operation.");
            operationDevice=address;operationTicket=operation.getString("id");operationOwner=store.scope();operationProof=false;
            this.address=address;this.name=name;operationAuthorization();return;
        }
        if(!store.secure("jwd.operation."+store.scope()).isEmpty())
            throw new IOException("Continue the pending recorder operation.");
        this.address=address;this.name=name;owner=store.scope();hardware="";recorder=new JSONObject();operation=new JSONObject();
        String cached=store.recorderIdentity(address).optString("hardware_id");
        expectedIdentity=cached.isEmpty()?"":canonical(cached);
        if(selected!=null&&!selected.isEmpty()){
            String requested=canonical(selected);
            if(!requested.equals(store.selectedRecorder())||!expectedIdentity.isEmpty()&&!requested.equals(expectedIdentity))
                throw new IOException("Recorder identity could not be verified.");
            expectedIdentity=requested;
        }
        compatibility=true;update("checking","Checking recorder ownership");
        if(expectedIdentity.isEmpty()){
            api("/api/v1/recorders/pairing-key",new JSONObject().put("confirm",true),this::sendPairingKey,null);
        }else{
            api("/api/v1/recorders/resolve",new JSONObject().put("hardware_id",expectedIdentity),result->{
                if(!"owned".equals(result.optString("state")))throw new IOException("The recorder's ownership could not be verified.");
                restoreForPairing(result,expectedIdentity,this::sendPairingKey);
            },null);
        }
    }
    private void restoreForPairing(JSONObject result,String actual,Done callback)throws Exception{
        JSONObject item=result.getJSONObject("recorder");
        if(!actual.equals(canonical(item.getString("hardware_id")))||!item.isNull("operation_id")&&!item.optString("operation_id").isEmpty())
            throw new IOException("Continue the pending recorder operation.");
        api("/api/v1/recorders/"+item.getString("id")+"/restore",new JSONObject(),restored->{
            if(!actual.equals(canonical(restored.getString("hardware_id"))))throw new IOException("Recorder identity could not be verified.");
            callback.accept(restored);
        },null);
    }
    private void sendPairingKey(JSONObject value)throws Exception{
        pairingKey=value.getString("device_key");
        if(!JwdProtocol.validKey(pairingKey))throw new IOException("Recorder authorization could not be verified.");
        auth="pairing";port.sendKey(pairingKey);
    }
    void confirmIdentity(String actual)throws Exception{
        if(operationIdentityRead){
            operationIdentityRead=false;
            if(!operationMatches(address)||!actual.equals(canonical(operation.getJSONObject("recorder").getString("hardware_id")))){
                fail("The recorder returned a different hardware ID. No recordings were accessed.");return;
            }
            hardware=actual;operationProof=true;operation.put("verified_radio",address);persist();
            if(auth.equals("confirm_current"))port.reconnect();
            else operationAccepted();
            return;
        }
        if(!compatibility||!"pairing_ack".equals(auth))throw new IOException("Confirm the connected recorder first.");
        if(!expectedIdentity.isEmpty()&&!expectedIdentity.equals(actual)){
            fail("The recorder returned a different hardware ID. No recordings were accessed.");return;
        }
        auth="pairing_verify";hardware=actual;
        api("/api/v1/recorders/resolve",new JSONObject().put("hardware_id",actual),result->{
            if("owned".equals(result.optString("state"))){
                restoreForPairing(result,actual,restored->{
                    if(!pairingKey.equals(restored.getString("device_key")))throw new IOException("Recorder authorization could not be verified.");
                    recorder=new JSONObject(restored.toString());recorder.remove("device_key");
                    store.deviceKey(address,pairingKey);store.recorderIdentity(address,recorder);
                    clearPairing();auth="owned";accepted();
                });
                return;
            }
            if(!"claim_required".equals(result.optString("state"))||!expectedIdentity.isEmpty())
                throw new IOException("Ask the owner to transfer this recorder.");
            JSONObject claim=new JSONObject().put("client_id",UUID.randomUUID().toString()).put("hardware_id",actual).put("name",name)
                    .put("confirm_card_recordings",true).put("account_key_only",true);
            api("/api/v1/recorders/claim",claim,prepared->{
                operation=prepared;stage="";before="";persist();
                api("/api/v1/recorders/operations/"+prepared.getString("id")+"/start",new JSONObject(),started->{
                    if(!pairingKey.equals(started.getString("device_key"))||!actual.equals(canonical(started.getJSONObject("recorder").getString("hardware_id"))))
                        throw new IOException("Recorder authorization could not be verified.");
                    operation=started;running=true;persist();clearPairing();auth="claim";complete("");
                },null);
            },null);
        },null);
    }
    boolean operationMatches(String address){
        return running&&!operationTicket.isEmpty()&&operationTicket.equals(operation.optString("id"))
                &&address.equals(operationDevice)&&store.scope().equals(operationOwner);
    }
    void operationAuthorization()throws Exception{
        if(!operationMatches(address))throw new IOException("Confirm the connected recorder first.");
        if(stage.equals("new_key_accepted")&&!operationProof){
            // A rejected old key alone cannot identify a card after resuming a journal.
            auth="confirm_current";port.sendKey(operation.getString("device_key"));
        }else authenticate();
    }
    void identity(String value,String address,String name,boolean selectedByUser)throws Exception{
        String actual=canonical(value);this.address=address;this.name=name;this.hardware=actual;owner=store.scope();
        String target=running?operation.getJSONObject("recorder").getString("hardware_id"):store.selectedRecorder();
        if(!target.isEmpty()&&!target.equals(actual)&&(running||!selectedByUser)){port.seek();return;}
        if(running){operation.put("verified_radio",address);persist();authenticate();return;}
        update("checking","Checking recorder ownership");
        api("/api/v1/recorders/resolve",new JSONObject().put("hardware_id",actual),result->{
            if(result.optString("state").equals("owned")){
                recorder=result.getJSONObject("recorder");
                if(!recorder.isNull("operation_id")&&!recorder.optString("operation_id").isEmpty()){
                    operation=new JSONObject().put("id",recorder.getString("operation_id"));update("recovery_required","Continue the pending recorder operation.");port.close(message);return;
                }
                api("/api/v1/recorders/"+recorder.getString("id")+"/restore",new JSONObject(),restored->{
                    recorder=new JSONObject(restored.toString());String key=recorder.getString("device_key");recorder.remove("device_key");
                    store.deviceKey(address,key);store.recorderIdentity(address,recorder);auth="owned";port.sendKey(key);
                },null);
            }else if(result.optString("state").equals("claim_required")){
                operation=new JSONObject();recorder=new JSONObject();update("claim_required","Confirm this recorder and its existing recordings.");
            }else{store.forgetRecorder(address);update("transfer_required","Ask the owner to transfer this recorder.");port.close(message);}
        },ignored->{
            JSONObject cached=store.recorderIdentity(address);
            if(!actual.equals(cached.optString("hardware_id"))||store.deviceKey(address).isEmpty())throw new IOException("Connect to the internet to restore recorder authorization.");
            String saved=store.secure(journal());if(!saved.isEmpty())throw new IOException("Connect to the internet to continue the pending recorder operation.");
            recorder=cached;auth="offline_owned";port.sendKey(store.deviceKey(address));
        });
    }
    void claim(String original,boolean confirmed)throws Exception{
        if(!confirmed||!state.equals("claim_required")||requesting)throw new IOException("Confirm the connected recorder first.");
        if(original.isEmpty()&&hardware.equals(rejectedClaimHardware))original=store.deviceKey(address);
        if(!original.isEmpty()&&!JwdProtocol.validKey(original))throw new IOException("Enter a 16-character key using letters and numbers");
        JSONObject body=new JSONObject().put("client_id",UUID.randomUUID().toString()).put("hardware_id",hardware).put("name",name).put("confirm_card_recordings",true);
        if(!original.isEmpty())body.put("original_key",original);
        api("/api/v1/recorders/claim",body,value->{operation=value;start(value.getString("id"));},null);
    }
    void start(String id)throws Exception{
        if(requesting)throw new IOException("Wait for the current recorder request.");
        owner=store.scope();api("/api/v1/recorders/operations/"+id+"/start",new JSONObject(),value->{
            String saved=store.secure(journal());
            operation=value;recorder=value.getJSONObject("recorder");
            if(value.optString("state").equals("completed")){store.secure(journal(),"");if(!value.optString("kind").equals("claim")&&!address.isEmpty())store.forgetRecorder(address);running=false;update("completed","Recorder operation completed");return;}
            JSONObject point=value.optJSONObject("checkpoint");before=point==null?"":point.optString("files_before");stage=point==null?"":point.optString("stage");
            if(hardware.equals(recorder.getString("hardware_id"))&&!address.isEmpty())operation.put("verified_radio",address);
            else if(!saved.isEmpty()){
                JSONObject local=new JSONObject(saved),item=local.optJSONObject("recorder");
                if(id.equals(local.optString("id"))&&item!=null&&recorder.getString("hardware_id").equals(item.optString("hardware_id"))&&local.has("verified_radio"))
                    operation.put("verified_radio",local.getString("verified_radio"));
            }
            running=true;persist();update("changing","Verifying recorder authorization");
            store.selectRecorder(recorder.getString("hardware_id"));
            if(hardware.equals(recorder.getString("hardware_id")))port.reconnect();else port.seek();
        },null);
    }
    private void authenticate()throws Exception{
        if(operation.optString("kind").equals("claim")){auth="claim";port.sendKey(operation.getString("device_key"));return;}
        if(stage.isEmpty()||stage.equals("inventory_saved")){auth="before";port.sendKey(operation.getString("previous_key"));}
        else if(stage.equals("new_key_accepted")){auth="reject_old";port.sendKey(operation.getString("previous_key"));}
        else{auth="new";port.sendKey(operation.getString("device_key"));}
    }
    void accepted()throws Exception{
        if(compatibility&&auth.equals("pairing")){auth="pairing_ack";port.verifyIdentity();return;}
        if(operationMatches(address)){operationIdentityRead=true;port.verifyIdentity();return;}
        operationAccepted();
    }
    private void operationAccepted()throws Exception{
        if(auth.equals("owned")||auth.equals("offline_owned")){update(auth,"Recorder connected");store.selectRecorder(hardware);store.rememberRecorder(address,name);port.ready();return;}
        if(auth.equals("claim")){complete("");return;}
        if(auth.equals("reject_old")){fail("The previous authorization is still accepted. Transfer was not completed.");return;}
        if(auth.equals("before")){port.inventory();return;}
        if(auth.equals("new")){
            if(stage.equals("old_key_rejected"))port.inventory();
            else checkpoint("new_key_accepted",()->port.reconnect());
        }
    }
    boolean rejected()throws Exception{
        if(compatibility){fail("The recorder rejected this account's key. Use the original account to check its ownership.");return true;}
        if(running&&auth.equals("claim")){
            api("/api/v1/recorders/operations/"+operation.getString("id")+"/claim-rejected",new JSONObject(),value->{
                rejectedClaimHardware=hardware;store.secure(journal(),"");operation=new JSONObject();stage="";running=false;
                update("claim_required","Device key was rejected. Use the original key; the recorder was not reset.");port.close(message);
            },null);return true;
        }
        if(auth.equals("reject_old")){checkpoint("old_key_rejected",()->port.reconnect());return true;}
        if(running&&auth.equals("new")&&stage.equals("rotation_requested")){
            // Power loss may have occurred before BLE&OFF. Re-verify the old key and inventory.
            stage="inventory_saved";persist();port.reconnect();return true;
        }
        fail("Device key was rejected. Use the original key; the recorder was not reset.");return true;
    }
    void disconnected(){if(compatibility)fail("Recorder disconnected before its hardware ID was verified.");else if(running||requesting)fail("Recorder disconnected. Continue the pending operation.");}
    interface Next{void run()throws Exception;}
    private void checkpoint(String next,Next action)throws Exception{
        api("/api/v1/recorders/operations/"+operation.getString("id")+"/checkpoint",new JSONObject().put("stage",next).put("files_before",before),value->{stage=next;persist();action.run();},null);
    }
    void inventory(List<String> entries)throws Exception{
        String hash=inventoryHash(entries);
        if(auth.equals("before")){
            if(!before.isEmpty()&&!before.equals(hash))throw new IOException("Card files changed. Keep the card unchanged while completing the transfer.");
            before=hash;checkpoint("inventory_saved",()->checkpoint("rotation_requested",()->port.unbind()));
        }else if(auth.equals("new")&&stage.equals("old_key_rejected")){
            if(!before.equals(hash))throw new IOException("Card file verification failed. Transfer was not completed.");complete(hash);
        }
    }
    private void complete(String after)throws Exception{
        JSONObject proof=new JSONObject().put("hardware_id",hardware).put("new_key_accepted",true);
        if(!after.isEmpty())proof.put("old_key_rejected",true).put("files_before",before).put("files_after",after);
        api("/api/v1/recorders/operations/"+operation.getString("id")+"/complete",proof,value->{
            boolean claim=operation.optString("kind").equals("claim");String key=operation.optString("device_key");
            running=false;clearOperationDevice();recorder=value.getJSONObject("recorder");store.secure(journal(),"");operation=new JSONObject();stage="";
            if(claim){rejectedClaimHardware="";store.deviceKey(address,key);store.recorderIdentity(address,recorder);store.selectRecorder(hardware);store.rememberRecorder(address,name);update("owned","Recorder connected");port.ready();}
            else{store.forgetRecorder(address);update("completed","Recorder operation completed");port.close(message);}
        },null);
    }
}
