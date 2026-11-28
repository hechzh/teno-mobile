package com.teno.app;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.*;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;
import java.util.*;

public final class Store {
    public static final String DEFAULT_URL="https://54-214-180-183.sslip.io";
    private final Context context;
    private final SharedPreferences prefs;
    public Store(Context c) {context=c.getApplicationContext();prefs=context.getSharedPreferences("teno",0);
        synchronized(Store.class){if(!prefs.contains("jwd.legacy_owner"))prefs.edit().putString("jwd.legacy_owner",scope()).commit();}}
    public String base(){return prefs.getString("server",DEFAULT_URL);}
    public void base(String url){prefs.edit().putString("server",url.replaceAll("/+$","")).apply();}
    public String name(){return prefs.getString("username","");}
    public String scope(){return prefs.getString("scope","");}
    public String language(){return "auto";}
    public String outputLanguage(){return UiLocale.locale(context).getLanguage().equals("zh")?"zh-CN":"en-US";}
    public void generationOptions(JSONObject draft,JSONObject args)throws Exception{
        if(!args.has("output_language"))return;
        String language=args.getString("output_language"),origin=args.optString("output_language_origin","interface");
        if(!(language.equals("zh-CN")||language.equals("en-US"))||!(origin.equals("interface")||origin.equals("override")))throw new IOException("Choose Chinese or English.");
        draft.put("output_language",language).put("output_language_origin",origin);
    }
    public void freezeGeneration(JSONObject draft)throws Exception{
        if(!draft.optBoolean("generation_frozen")||draft.optString("output_language").isEmpty()){
            if(draft.optString("template_id","@default").equals("@default")){
                JSONObject settings=new JSONObject(context.getSharedPreferences("teno.personal",0).getString("settings."+scope(),"{}"));
                draft.put("template_id",settings.optString("default_template_id","teno:brief")).put("template_origin","account");
            }else if(!draft.has("template_origin"))draft.put("template_origin","selection");
            if(draft.optString("output_language").isEmpty())
                draft.put("output_language",outputLanguage()).put("output_language_origin","interface");
            draft.put("generation_frozen",true).put("template_frozen",true);
        }
    }
    public JSONObject recorderOptions(String id)throws Exception{
        JSONObject value=new JSONObject(prefs.getString("note.options."+scope()+"."+id,"{}"));
        value.put("template_id",recorderTemplate(id));return value;
    }
    public void recorderOptions(String id,JSONObject value)throws Exception{
        JSONObject current=recorderOptions(id);generationOptions(current,value);
        recorderTemplate(id,value.getString("template_id"));
        if(!prefs.edit().putString("note.options."+scope()+"."+id,current.toString()).commit())throw new IOException("Could not save generation options.");
    }
    public void language(String v){prefs.edit().putString("language","auto").apply();}
    public boolean recordingOptionsSet(){return prefs.getBoolean("recording_options."+scope(),false);}
    // A missing account preference means automatic processing. Never overwrite an
    // explicit opt-out, and never use the first-recording dialog as an upload gate.
    public boolean autoUpload(){return prefs.getBoolean("auto_upload."+scope(),true);}
    public boolean liveDefault(){return false;} // Legacy setting cannot enable recording-time transcription.
    public void recordingOptions(boolean cloud,boolean live){prefs.edit().putBoolean("recording_options."+scope(),true).putBoolean("auto_upload."+scope(),cloud).putBoolean("live_default",false).commit();}
    private boolean legacyOwner(){return !scope().isEmpty()&&scope().equals(prefs.getString("jwd.legacy_owner",""));}
    public String recorderAddress(){return prefs.getString("jwd.last_address."+scope(),legacyOwner()?prefs.getString("jwd.last_address",""):"");}
    public String recorderName(){return prefs.getString("jwd.last_name."+scope(),legacyOwner()?prefs.getString("jwd.last_name","Recorder"):"Recorder");}
    public void rememberRecorder(String address,String name){prefs.edit().putString("jwd.last_address."+scope(),address).putString("jwd.last_name."+scope(),name).commit();}
    public String selectedRecorder(){return prefs.getString("jwd.selected."+scope(),"");}
    public void selectRecorder(String hardware){prefs.edit().putString("jwd.selected."+scope(),hardware).putString("jwd.last_address."+scope(),"").commit();}
    public JSONObject recorderIdentity(String address)throws Exception{return new JSONObject(prefs.getString("jwd.identity."+scope()+"."+address,"{}"));}
    public void recorderIdentity(String address,JSONObject value)throws Exception{
        if(!prefs.edit().putString("jwd.identity."+scope()+"."+address,value.toString()).commit())throw new IOException("Could not save recorder identity.");
    }
    public void forgetRecorder(String address)throws Exception{
        secure("jwd.account_key."+scope()+"."+address,"");
        // Keep a previously attested hardware ID so an old owner must recheck the server.
        String known=recorderIdentity(address).optString("hardware_id");
        recorderIdentity(address,known.isEmpty()?new JSONObject():new JSONObject().put("hardware_id",known));
        prefs.edit().putBoolean("jwd.revoked."+scope()+"."+address,true).putString("jwd.last_address."+scope(),"").remove("jwd.selected."+scope()).commit();
    }
    public synchronized String secure(String name)throws Exception{
        String value=prefs.getString(name,"");if(value.isEmpty())return "";String[] parts=value.split(":");
        if(parts.length!=2)throw new IOException("Saved authorization is unreadable.");
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Base64.decode(parts[0],Base64.NO_WRAP)));
        return new String(c.doFinal(Base64.decode(parts[1],Base64.NO_WRAP)),StandardCharsets.UTF_8);
    }
    public synchronized void secure(String name,String value)throws Exception{
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key());
        String encoded=value.isEmpty()?"":Base64.encodeToString(c.getIV(),Base64.NO_WRAP)+":"+Base64.encodeToString(c.doFinal(value.getBytes(StandardCharsets.UTF_8)),Base64.NO_WRAP);
        if(!prefs.edit().putString(name,encoded).commit())throw new IOException("Could not save recorder authorization.");
    }
    private String deviceRecordKey(String address,String dir,String name,long seconds){return "jwd.synced."+scope()+"."+address+"."+dir+"."+name+"."+seconds;}
    public boolean deviceRecordSynced(String address,String dir,String name,long seconds){return prefs.contains(deviceRecordKey(address,dir,name,seconds));}
    public void deviceRecordSynced(String address,String dir,String name,long seconds,String id){prefs.edit().putString(deviceRecordKey(address,dir,name,seconds),id).commit();}
    public String pendingDeviceRecord(String address){return prefs.getString("jwd.pending."+scope()+"."+address,"");}
    public void pendingDeviceRecord(String address,String name){prefs.edit().putString("jwd.pending."+scope()+"."+address,name).commit();}
    public boolean nativePreferencesSet(){return prefs.getBoolean("native_prefs_0_3_"+scope(),false);}
    public void markNativePreferences(){prefs.edit().putBoolean("native_prefs_0_3_"+scope(),true).putString("summary_language","en-US").apply();}
    public void identity(String username,String id)throws Exception{
        String hash=Base64.encodeToString(MessageDigest.getInstance("SHA-256").digest((base()+id).getBytes(StandardCharsets.UTF_8)),Base64.NO_WRAP|Base64.URL_SAFE).replace("=","");
        prefs.edit().putString("username",username).putString("scope",hash).commit();
    }
    private SecretKey key()throws Exception{
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");ks.load(null);
        if(!ks.containsAlias("teno.session")){
            KeyGenerator gen=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
            gen.init(new KeyGenParameterSpec.Builder("teno.session",KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());gen.generateKey();
        }
        return (SecretKey)ks.getKey("teno.session",null);
    }
    public synchronized void tokens(JSONObject data)throws Exception{
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key());
        String encoded=Base64.encodeToString(c.getIV(),Base64.NO_WRAP)+":"+Base64.encodeToString(c.doFinal(data.toString().getBytes(StandardCharsets.UTF_8)),Base64.NO_WRAP);
        prefs.edit().putString("session",encoded).commit();
    }
    public synchronized String token(String field){
        try{
            String[] parts=prefs.getString("session","").split(":");if(parts.length!=2)return "";
            Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Base64.decode(parts[0],Base64.NO_WRAP)));
            return new JSONObject(new String(c.doFinal(Base64.decode(parts[1],Base64.NO_WRAP)),StandardCharsets.UTF_8)).optString(field);
        }catch(Exception e){return "";}
    }
    public synchronized String deviceKey(String address)throws Exception{
        if(scope().isEmpty())return "";
        String value=secure("jwd.account_key."+scope()+"."+address);
        if(!value.isEmpty())return value;
        return legacyOwner()&&!prefs.getBoolean("jwd.revoked."+scope()+"."+address,false)?secure("jwd.key."+address):"";
    }
    public synchronized void deviceKey(String address,String value)throws Exception{
        if(!JwdProtocol.validKey(value))throw new IOException("Enter a 16-character key using letters and numbers");
        if(scope().isEmpty())throw new IOException("Sign in to connect your recorder.");
        secure("jwd.account_key."+scope()+"."+address,value);
    }
    public void logout(){prefs.edit().remove("session").remove("scope").remove("username").commit();}
    public String recorderNotes(String address,String name){return prefs.getString("jwd.notes."+scope()+"."+address+"."+name,"");}
    public void recorderNotes(String address,String name,String notes){prefs.edit().putString("jwd.notes."+scope()+"."+address+"."+name,notes).commit();}
    public String recorderTemplate(String id){return prefs.getString("note.template."+scope()+"."+id,"@default");}
    public void recorderTemplate(String id,String value){prefs.edit().putString("note.template."+scope()+"."+id,value).commit();}
    public File folder(){File f=new File(context.getFilesDir(),"drafts/"+scope());f.mkdirs();return f;}
    public static synchronized void save(File folder,JSONObject draft)throws Exception{
        File out=new File(folder,draft.getString("id")+".json");File tmp=new File(folder,draft.getString("id")+".tmp");
        try(FileOutputStream f=new FileOutputStream(tmp)){f.write(draft.toString().getBytes(StandardCharsets.UTF_8));f.getFD().sync();}
        if(!tmp.renameTo(out))throw new IOException("Recording details could not be saved");
    }
    public synchronized JSONArray drafts(){
        JSONArray result=new JSONArray();File[] files=folder().listFiles((d,n)->n.endsWith(".json"));if(files==null)return result;
        Arrays.sort(files,Comparator.comparingLong(File::lastModified).reversed());
        for(File f:files)try{JSONObject d=new JSONObject(new String(Files.readAllBytes(f.toPath()),StandardCharsets.UTF_8));
            if(d.optString("recording_id").isEmpty()&&d.optString("file_id").isEmpty()&&d.optString("output_language").isEmpty()&&!d.optString("status").equals("recording")){
                d.put("output_language",outputLanguage()).put("output_language_origin","interface");save(d);
            }result.put(d);}catch(Exception ignored){}
        return result;
    }
    public JSONObject draft(String id)throws Exception{return new JSONObject(new String(Files.readAllBytes(new File(folder(),id+".json").toPath()),StandardCharsets.UTF_8));}
    public void save(JSONObject draft)throws Exception{save(folder(),draft);}
    public void deleteDraft(JSONObject d)throws Exception{new File(folder(),d.getString("id")+".json").delete();new File(d.getString("path")).delete();}
    public JSONObject newDraft(String title,String ext)throws Exception{
        String id=UUID.randomUUID().toString();return new JSONObject().put("id",id).put("title",title).put("path",new File(folder(),id+ext).getAbsolutePath()).put("language",language()).put("created_at",java.time.Instant.now().toString()).put("status","local").put("scope",scope());
    }
    public String workspaceFolder() {
        return prefs.getString("workspace.folder." + scope(), "");
    }
    public String checkedWorkspaceFolder(String folder) throws IOException {
        if (!folder.isEmpty() && !folder.matches("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"))
            throw new IOException("Invalid workspace.");
        return folder;
    }
    public void workspaceFolder(String owner, String folder) throws Exception {
        if (owner.isEmpty() || !owner.equals(scope())) throw new IOException("Account changed.");
        if (!prefs.edit().putString("workspace.folder." + owner, checkedWorkspaceFolder(folder)).commit())
            throw new IOException("Could not save the workspace.");
    }
    private String recorderStartKey(String address, String name) {
        return "workspace.recorder." + scope() + "." + address + "|" + name.replaceFirst("\\.[^.]+$", "");
    }
    public void rememberRecorderStart(String address, String name, String folder, String recordedAt) throws JSONException {
        JSONObject data = new JSONObject().put("folder_id", folder).put("recorded_at", recordedAt);
        prefs.edit().putString(recorderStartKey(address, name), data.toString()).commit();
    }
    public JSONObject recorderStart(String address, String name) throws JSONException {
        return new JSONObject(prefs.getString(recorderStartKey(address, name), "{}"));
    }
    public void clearRecorderStart(String address, String name) {
        prefs.edit().remove(recorderStartKey(address, name)).apply();
    }
    public void recoverRecordings(){
        if(RecorderService.active||RecorderService.finishing||scope().isEmpty())return;
        JSONArray all=drafts();for(int i=0;i<all.length();i++){JSONObject d=all.optJSONObject(i);if(d==null||!d.optString("status").equals("recording"))continue;
            try{File file=new File(d.getString("path"));long bytes=Math.max(0,file.length()-44);boolean valid=bytes>=3200&&bytes%2==0&&file.getName().endsWith(".wav");
                if(valid)try(RandomAccessFile audio=new RandomAccessFile(file,"rw")){byte[] header=new byte[4];audio.readFully(header);valid=new String(header,StandardCharsets.US_ASCII).equals("RIFF");if(valid){audio.seek(0);audio.write(JwdAudio.wavHeader(bytes));audio.getFD().sync();}}
                d.put("status",valid?"local":"invalid").put("duration_ms",valid?bytes/32:0).put("live_complete",false).put("live_session_id","").put("error",valid?"Recording was interrupted. The saved audio is ready to upload.":"Recording was interrupted before usable audio was saved.");save(d);
                if(valid)UploadQueue.saved(context,d);
            }catch(Exception ignored){}
        }
    }
}
