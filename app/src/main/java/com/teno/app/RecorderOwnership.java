package com.teno.app;

import android.os.Handler;
import org.json.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;

/** Separates daily account-key authorization from operations that require protocol identity. */
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
    private String directState="", directKey="";
    private boolean dailyOnline;
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
    boolean blocked(){return running||requesting||!state.equals("authorized")&&!state.equals("owned")&&!state.equals("offline_owned");}
    boolean changing(){return running||!directState.isEmpty();}
    boolean authorizingDaily(){return !directState.isEmpty();}
    boolean pendingOperation(){return running;}
    String hardware(){return hardware;}
    private void clearDaily(){directState="";directKey="";dailyOnline=false;}
    String syncIdentity(){return !hardware.isEmpty()?hardware:recorder.optString("hardware_id");}
    private String offlineGuard(String route){return "jwd.authorization_blocked."+owner+"."+route;}
    private void clearOperationDevice(){operationDevice="";operationTicket="";operationOwner="";operationProof=false;operationIdentityRead=false;}
    void cancel(){clearOperationDevice();clearDaily();generation++;running=false;requesting=false;auth="";state="disconnected";}
    void connectionAttempt(){clearDaily();generation++;requesting=false;auth="";if(!running){hardware="";recorder=new JSONObject();state="disconnected";}}
    void dispose(){cancel();network.shutdownNow();}
    private void update(String state,String message){this.state=state;this.message=message;port.changed();}
    private String journal(){return "jwd.operation."+owner;}
    private void persist()throws Exception{operation.put("local_stage",stage).put("files_before",before);store.secure(journal(),operation.toString());}
    void fail(String text){boolean daily=authorizingDaily();clearOperationDevice();clearDaily();generation++;running=false;requesting=false;auth="";update(daily?"authorization_failed":"recovery_required",text);port.close(text);}
    interface Done{void accept(JSONObject value)throws Exception;}
    private void api(String path,JSONObject body,Done done,Done offline){
        long ticket=++generation;String scope=store.scope();boolean daily=authorizingDaily();requesting=true;port.changed();
        network.execute(()->{JSONObject value=null;Exception failure=null;
            if(ticket!=generation||!scope.equals(store.scope())||JwdService.accountClosing)return;
            try{Api api=daily?new Api(store,4000,6500):new Api(store);value=body==null?api.get(path):api.post(path,body);}catch(Exception e){failure=e;}
            JSONObject result=value;Exception error=failure;handler.post(()->{
                if(ticket!=generation||!scope.equals(store.scope())||store.token("access_token").isEmpty()||JwdService.accountClosing)return;
                requesting=false;
                try{
                    String gate="device."+address;
                    if(error==null){
                        done.accept(result);
                    }else if(offline!=null&&error instanceof IOException&&!(error instanceof Api.Failure)
                            &&store.secure(offlineGuard(gate)).isEmpty()&&store.secure(offlineGuard("account")).isEmpty()){
                        offline.accept(new JSONObject());
                    }else{
                        if(daily&&error instanceof Api.Failure&&((Api.Failure)error).status<500){
                            store.secure(offlineGuard(gate),"blocked");
                            if(path.endsWith("/connection-key")&&"RECORDER_OPERATION_PENDING".equals(((Api.Failure)error).code))
                                store.secure(offlineGuard("account"),"blocked");
                        }
                        fail(error.getMessage());
                    }
                }
                catch(Exception e){fail(e.getMessage());}
            });
        });
    }
    void authorizeDaily(String address,String name,String original)throws Exception{
        if(running||requesting||!store.secure("jwd.operation."+store.scope()).isEmpty())
            throw new IOException("Continue the pending recorder operation.");
        this.address=address;this.name=name;owner=store.scope();hardware="";operation=new JSONObject();
        recorder=store.recorderIdentity(address);
        String cachedKey=store.deviceKey(address);
        String known=recorder.optString("hardware_id");
        dailyOnline=false;directState=known.isEmpty()?"authorized":"owned";
        update("checking","Connected. Checking device key…");
        Done offline=ignored->{
            String receipt=store.secure("jwd.accepted."+owner+"."+address);
            boolean previouslyAccepted=receipt.isEmpty()?address.equals(store.recorderAddress()):receipt.equals(inventoryHash(Collections.singletonList(cachedKey)));
            if(!previouslyAccepted||cachedKey.isEmpty()||!original.isEmpty()&&!original.equals(cachedKey))
                throw new IOException("Connect to the internet to restore recorder authorization.");
            if(!known.isEmpty())directState="offline_owned";
            sendDaily(cachedKey);
        };
        if(known.isEmpty()){
            String candidate=original.isEmpty()?cachedKey:original;
            JSONObject request=new JSONObject();
            if(!candidate.isEmpty()){
                if(!JwdProtocol.validKey(candidate))throw new IOException("Enter a 16-character key using letters and numbers");
                request.put("original_key",candidate);
            }
            api("/api/v1/recorders/connection-key",request,value->{
                dailyOnline=true;sendDaily(value.getString("device_key"));
            },offline);
        }else{
            String expected=canonical(known);
            api("/api/v1/recorders/resolve",new JSONObject().put("hardware_id",expected),result->{
                if(!"owned".equals(result.optString("state"))){
                    store.secure(offlineGuard("device."+address),"blocked");
                    throw new IOException("Ask the owner to transfer this recorder.");
                }
                JSONObject item=result.getJSONObject("recorder");
                if(!expected.equals(canonical(item.getString("hardware_id")))||!item.isNull("operation_id")&&!item.optString("operation_id").isEmpty()){
                    store.secure(offlineGuard("device."+address),"blocked");
                    throw new IOException("Continue the pending recorder operation.");
                }
                restoreDaily(item,expected,original,offline);
            },offline);
        }
    }
    private void restoreDaily(JSONObject item,String expected,String original,Done offline)throws Exception{
        api("/api/v1/recorders/"+item.getString("id")+"/restore",new JSONObject(),result->{
            if(!expected.equals(canonical(result.getString("hardware_id"))))throw new IOException("Recorder identity could not be verified.");
            String key=result.getString("device_key");
            if(!original.isEmpty()&&!original.equals(key))throw new IOException("The original key does not match this account's recorder.");
            recorder=new JSONObject(result.toString());recorder.remove("device_key");
            dailyOnline=true;sendDaily(key);
        },offline);
    }
    private void sendDaily(String key)throws Exception{
        if(!JwdProtocol.validKey(key))throw new IOException("Enter a 16-character key using letters and numbers");
        directKey=key;auth="direct";port.sendKey(key);
    }
    void compatibility(String address,String name,String selected)throws Exception{
        if(requesting||!running)throw new IOException("Continue the pending recorder operation.");
        String target=canonical(operation.getJSONObject("recorder").getString("hardware_id"));
        String cached=store.recorderIdentity(address).optString("hardware_id");
        if(!cached.isEmpty()&&!target.equals(canonical(cached)))throw new IOException("Recorder identity could not be verified.");
        boolean chosen=selected!=null&&!selected.isEmpty()&&target.equals(canonical(selected))&&target.equals(store.selectedRecorder());
        if(cached.isEmpty()&&!chosen&&!address.equals(operation.optString("verified_radio")))
            throw new IOException("Select the registered recorder for this operation.");
        operationDevice=address;operationTicket=operation.getString("id");operationOwner=store.scope();operationProof=false;
        this.address=address;this.name=name;operationAuthorization();
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
        throw new IOException("Confirm the connected recorder first.");
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
                    store.recorderIdentity(address,recorder);store.secure(offlineGuard("device."+address),"blocked");
                    operation=new JSONObject().put("id",recorder.getString("operation_id"));update("recovery_required","Continue the pending recorder operation.");port.close(message);return;
                }
                api("/api/v1/recorders/"+recorder.getString("id")+"/restore",new JSONObject(),restored->{
                    recorder=new JSONObject(restored.toString());String key=recorder.getString("device_key");recorder.remove("device_key");
                    if(!actual.equals(canonical(recorder.getString("hardware_id"))))throw new IOException("Recorder identity could not be verified.");
                    directState="owned";dailyOnline=true;sendDaily(key);
                },null);
            }else if(result.optString("state").equals("claim_required")){
                operation=new JSONObject();recorder=new JSONObject();update("claim_required","Confirm this recorder and its existing recordings.");
            }else{
                store.recorderIdentity(address,new JSONObject().put("hardware_id",actual));
                store.forgetRecorder(address);store.secure(offlineGuard("device."+address),"blocked");
                update("transfer_required","Ask the owner to transfer this recorder.");port.close(message);
            }
        },ignored->{
            JSONObject cached=store.recorderIdentity(address);
            if(!actual.equals(cached.optString("hardware_id"))||store.deviceKey(address).isEmpty())throw new IOException("Connect to the internet to restore recorder authorization.");
            String saved=store.secure(journal());if(!saved.isEmpty())throw new IOException("Connect to the internet to continue the pending recorder operation.");
            recorder=cached;auth="offline_owned";port.sendKey(store.deviceKey(address));
        });
    }
    void claim(String original,boolean confirmed)throws Exception{
        if(!confirmed||!state.equals("claim_required")||requesting)throw new IOException("Confirm the connected recorder first.");
        if(original.isEmpty())original=store.deviceKey(address);
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
        if(authorizingDaily()&&auth.equals("direct")){
            if(!owner.equals(store.scope())||store.token("access_token").isEmpty()||JwdService.accountClosing)return;
            store.deviceKey(address,directKey);
            store.secure("jwd.accepted."+owner+"."+address,inventoryHash(Collections.singletonList(directKey)));
            if(dailyOnline){
                store.secure(offlineGuard("device."+address),"");
                if(directState.equals("authorized"))store.secure(offlineGuard("account"),"");
            }
            if(!recorder.optString("hardware_id").isEmpty())store.recorderIdentity(address,recorder);
            store.selectRecorder(recorder.optString("hardware_id"));store.rememberRecorder(address,name);
            String completed=directState;clearDaily();auth="";update(completed,"Recorder connected");port.ready();return;
        }
        if(operationMatches(address)){operationIdentityRead=true;port.verifyIdentity();return;}
        operationAccepted();
    }
    private void operationAccepted()throws Exception{
        if(auth.equals("offline_owned")){update(auth,"Recorder connected");store.selectRecorder(hardware);store.rememberRecorder(address,name);port.ready();return;}
        if(auth.equals("claim")){complete("");return;}
        if(auth.equals("reject_old")){fail("The previous authorization is still accepted. Transfer was not completed.");return;}
        if(auth.equals("before")){port.inventory();return;}
        if(auth.equals("new")){
            if(stage.equals("old_key_rejected"))port.inventory();
            else checkpoint("new_key_accepted",()->port.reconnect());
        }
    }
    boolean rejected()throws Exception{
        if(authorizingDaily()){fail("Device key was rejected. Use the original key; the recorder was not reset.");return true;}
        if(running&&auth.equals("claim")){
            api("/api/v1/recorders/operations/"+operation.getString("id")+"/claim-rejected",new JSONObject(),value->{
                store.secure(journal(),"");operation=new JSONObject();stage="";running=false;
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
    void disconnected(){if(authorizingDaily())fail("Recorder disconnected before authorization finished.");else if(running||requesting)fail("Recorder disconnected. Continue the pending operation.");}
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
            if(claim){store.deviceKey(address,key);store.recorderIdentity(address,recorder);store.selectRecorder(hardware);store.rememberRecorder(address,name);update("owned","Recorder connected");port.ready();}
            else{store.forgetRecorder(address);update("completed","Recorder operation completed");port.close(message);}
        },null);
    }
}
