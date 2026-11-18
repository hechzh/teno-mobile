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
        void sendKey(String key); void reconnect(); void inventory(); void unbind();
        void ready(); void changed(); void close(String message); void seek();
    }
    private final Store store; private final Handler handler; private final Port port;
    private final ExecutorService network=Executors.newSingleThreadExecutor();
    private JSONObject operation=new JSONObject(), recorder=new JSONObject();
    private String owner="",address="",name="",hardware="",stage="",auth="",before="";
    private long generation;
    private boolean running,requesting;
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
    boolean changing(){return running;}
    String hardware(){return hardware;}
    void cancel(){generation++;running=false;requesting=false;auth="";state="disconnected";}
    void dispose(){cancel();network.shutdownNow();}
    private void update(String state,String message){this.state=state;this.message=message;port.changed();}
    private String journal(){return "jwd.operation."+owner;}
    private void persist()throws Exception{operation.put("local_stage",stage).put("files_before",before);store.secure(journal(),operation.toString());}
    void fail(String text){generation++;running=false;requesting=false;auth="";update("recovery_required",text);port.close(text);}
    interface Done{void accept(JSONObject value)throws Exception;}
    private void api(String path,JSONObject body,Done done,Done offline){
        long ticket=++generation;String scope=store.scope();requesting=true;port.changed();
        network.execute(()->{JSONObject value=null;Exception failure=null;
            try{Api api=new Api(store);value=body==null?api.get(path):api.post(path,body);}catch(Exception e){failure=e;}
            JSONObject result=value;Exception error=failure;handler.post(()->{
                if(ticket!=generation||!scope.equals(store.scope())||store.token("access_token").isEmpty()||JwdService.accountClosing)return;
                requesting=false;
                try{if(error==null)done.accept(result);else if(offline!=null&&!(error instanceof Api.Failure))offline.accept(new JSONObject());else fail(error.getMessage());}
                catch(Exception e){fail(e.getMessage());}
            });
        });
    }
    void identity(String value,String address,String name)throws Exception{
        String actual=canonical(value);this.address=address;this.name=name;this.hardware=actual;owner=store.scope();
        String target=running?operation.getJSONObject("recorder").getString("hardware_id"):store.selectedRecorder();
        if(!target.isEmpty()&&!target.equals(actual)){port.seek();return;}
        if(running){authenticate();return;}
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
        if(original.isEmpty())original=store.deviceKey(address);
        JSONObject body=new JSONObject().put("client_id",UUID.randomUUID().toString()).put("hardware_id",hardware).put("name",name).put("confirm_card_recordings",true);
        if(!original.isEmpty())body.put("original_key",original);
        api("/api/v1/recorders/claim",body,value->{operation=value;start(value.getString("id"));},null);
    }
    void start(String id)throws Exception{
        if(requesting)throw new IOException("Wait for the current recorder request.");
        owner=store.scope();api("/api/v1/recorders/operations/"+id+"/start",new JSONObject(),value->{
            operation=value;recorder=value.getJSONObject("recorder");
            if(value.optString("state").equals("completed")){store.secure(journal(),"");if(!value.optString("kind").equals("claim")&&!address.isEmpty())store.forgetRecorder(address);running=false;update("completed","Recorder operation completed");return;}
            JSONObject point=value.optJSONObject("checkpoint");before=point==null?"":point.optString("files_before");stage=point==null?"":point.optString("stage");
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
        if(auth.equals("owned")||auth.equals("offline_owned")){update(auth,"Recorder connected");store.rememberRecorder(address,name);port.ready();return;}
        if(auth.equals("claim")){complete("");return;}
        if(auth.equals("reject_old")){fail("The previous authorization is still accepted. Transfer was not completed.");return;}
        if(auth.equals("before")){port.inventory();return;}
        if(auth.equals("new")){
            if(stage.equals("old_key_rejected"))port.inventory();
            else checkpoint("new_key_accepted",()->port.reconnect());
        }
    }
    boolean rejected()throws Exception{
        if(auth.equals("reject_old")){checkpoint("old_key_rejected",()->port.reconnect());return true;}
        if(running&&auth.equals("new")&&stage.equals("rotation_requested")){
            // Power loss may have occurred before BLE&OFF. Re-verify the old key and inventory.
            stage="inventory_saved";persist();port.reconnect();return true;
        }
        fail("Device key was rejected. Use the original key; the recorder was not reset.");return true;
    }
    void disconnected(){if(running||requesting)fail("Recorder disconnected. Continue the pending operation.");}
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
            running=false;recorder=value.getJSONObject("recorder");store.secure(journal(),"");operation=new JSONObject();stage="";
            if(claim){store.deviceKey(address,key);store.recorderIdentity(address,recorder);store.rememberRecorder(address,name);update("owned","Recorder connected");port.ready();}
            else{store.forgetRecorder(address);update("completed","Recorder operation completed");port.close(message);}
        },null);
    }
}
