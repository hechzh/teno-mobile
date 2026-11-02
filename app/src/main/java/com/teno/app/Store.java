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
    public Store(Context c) {context=c.getApplicationContext();prefs=context.getSharedPreferences("teno",0);}
    public String base(){return prefs.getString("server",DEFAULT_URL);}
    public void base(String url){prefs.edit().putString("server",url.replaceAll("/+$","")).apply();}
    public String name(){return prefs.getString("username","");}
    public String scope(){return prefs.getString("scope","");}
    public String language(){return prefs.getString("language","zh-CN");}
    public void language(String v){prefs.edit().putString("language",v).apply();}
    public boolean recordingOptionsSet(){return prefs.getBoolean("recording_options."+scope(),false);}
    public boolean autoUpload(){return recordingOptionsSet()&&prefs.getBoolean("auto_upload."+scope(),false);}
    public boolean wifiUpload(){return prefs.getBoolean("wifi_upload."+scope(),false);}
    public boolean liveDefault(){return prefs.getBoolean("live_default",true);}
    public void recordingOptions(boolean cloud,boolean wifi,boolean live){prefs.edit().putBoolean("recording_options."+scope(),true).putBoolean("auto_upload."+scope(),cloud).putBoolean("wifi_upload."+scope(),wifi).putBoolean("live_default",live).commit();}
    public String recorderAddress(){return prefs.getString("jwd.last_address","");}
    public String recorderName(){return prefs.getString("jwd.last_name","Recorder");}
    public void rememberRecorder(String address,String name){prefs.edit().putString("jwd.last_address",address).putString("jwd.last_name",name).commit();}
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
        String value=prefs.getString("jwd.key."+address,"");if(value.isEmpty())return "";
        String[] parts=value.split(":");
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Base64.decode(parts[0],Base64.NO_WRAP)));
        return new String(c.doFinal(Base64.decode(parts[1],Base64.NO_WRAP)),StandardCharsets.US_ASCII);
    }
    public synchronized void deviceKey(String address,String value)throws Exception{
        if(!JwdProtocol.validKey(value))throw new IOException("Enter a 16-character key using letters and numbers");
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key());
        String encoded=Base64.encodeToString(c.getIV(),Base64.NO_WRAP)+":"+Base64.encodeToString(c.doFinal(value.getBytes(StandardCharsets.US_ASCII)),Base64.NO_WRAP);
        if(!prefs.edit().putString("jwd.key."+address,encoded).commit())throw new IOException("The key could not be saved. No binding command was sent.");
    }
    public void logout(){prefs.edit().remove("session").remove("scope").remove("username").commit();}
    public File folder(){File f=new File(context.getFilesDir(),"drafts/"+scope());f.mkdirs();return f;}
    public static synchronized void save(File folder,JSONObject draft)throws Exception{
        File out=new File(folder,draft.getString("id")+".json");File tmp=new File(folder,draft.getString("id")+".tmp");
        try(FileOutputStream f=new FileOutputStream(tmp)){f.write(draft.toString().getBytes(StandardCharsets.UTF_8));f.getFD().sync();}
        if(!tmp.renameTo(out))throw new IOException("Recording details could not be saved");
    }
    public synchronized JSONArray drafts(){
        JSONArray result=new JSONArray();File[] files=folder().listFiles((d,n)->n.endsWith(".json"));if(files==null)return result;
        Arrays.sort(files,Comparator.comparingLong(File::lastModified).reversed());
        for(File f:files)try{result.put(new JSONObject(new String(Files.readAllBytes(f.toPath()),StandardCharsets.UTF_8)));}catch(Exception ignored){}
        return result;
    }
    public JSONObject draft(String id)throws Exception{return new JSONObject(new String(Files.readAllBytes(new File(folder(),id+".json").toPath()),StandardCharsets.UTF_8));}
    public void save(JSONObject draft)throws Exception{save(folder(),draft);}
    public void deleteDraft(JSONObject d)throws Exception{new File(folder(),d.getString("id")+".json").delete();new File(d.getString("path")).delete();}
    public JSONObject newDraft(String title,String ext)throws Exception{
        String id=UUID.randomUUID().toString();return new JSONObject().put("id",id).put("title",title).put("path",new File(folder(),id+ext).getAbsolutePath()).put("language",language()).put("created_at",java.time.Instant.now().toString()).put("status","local").put("scope",scope());
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
