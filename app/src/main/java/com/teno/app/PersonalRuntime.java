package com.teno.app;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.database.Cursor;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.SystemClock;
import android.provider.CalendarContract;
import android.provider.OpenableColumns;
import android.provider.MediaStore;
import android.view.*;
import android.widget.*;
import androidx.core.content.FileProvider;
import org.json.*;
import java.io.*;
import java.nio.file.Files;
import java.time.Instant;
import java.util.*;
import static com.teno.app.RuntimeMessages.*;

/** Android-only personal features. File paths, calendar permissions and locks stay native. */
final class PersonalRuntime {
    static final Set<String> MEDIA=new HashSet<>(Arrays.asList("wav","mp3","m4a","aac","flac","ogg","mp4","mov","3gp","webm"));
    static final Set<String> DOCS=new HashSet<>(Arrays.asList("pdf","doc","docx","pptx","txt","md","msg","png","jpg","jpeg"));
    final NativeRuntime runtime; final MainActivity activity; final Store store;
    final android.content.SharedPreferences prefs;
    private Result<String> pickerResult,authResult;
    private JSONObject pickerArgs=new JSONObject(); private String pickerOwner="";
    private File cameraFile; private View lockCover; private boolean unlocked,authenticating,enablingLock;
    private long pausedAt; private String unlockedScope="";
    private MediaRecorder voice; private File voiceFile; private AlertDialog voiceDialog;
    PersonalRuntime(NativeRuntime r){runtime=r;activity=r.activity;store=r.store;prefs=activity.getSharedPreferences("teno.personal",0);}
    String key(String suffix){return suffix+"."+store.scope();}
    static String extension(String name){int at=name.lastIndexOf('.');return at<0?"":name.substring(at+1).toLowerCase(Locale.ROOT);}
    static long limit(String ext)throws IOException{
        if(MEDIA.contains(ext))return 262144000L;
        if(Arrays.asList("png","jpg","jpeg").contains(ext))return 20000000L;
        if(Arrays.asList("txt","md").contains(ext))return 2000000L;
        if(DOCS.contains(ext))return 15000000L;
        if(ext.equals("ics"))return 1048576L;
        throw new IOException("Choose a supported audio, video, document or image file.");
    }
    void command(String command,String json,Result<String> result){
        try{
            JSONObject args=json==null?new JSONObject():new JSONObject(json);
            if(command.equals("preferences")){result.success(new JSONObject().put("personal_core",true).put("settings",new JSONObject(prefs.getString(key("settings"),"{}"))).put("app_lock",prefs.getBoolean(key("lock"),false)).put("pending_imports",pending().length()).toString());return;}
            if(command.equals("cache_preferences")){runtime.signedIn();prefs.edit().putString(key("settings"),args.toString()).putBoolean(key("notifications"),args.optBoolean("notifications",true)).commit();result.success("{}");return;}
            if(command.equals("app_lock")){setLock(args.optBoolean("enabled"),result);return;}
            if(command.equals("dictate")){runtime.signedIn();activity.permissions(new String[]{Manifest.permission.RECORD_AUDIO},()->startDictation(result),e->result.error(runtime.failure(e)));return;}
            if(command.equals("notifications")){
                Runnable save=()->{prefs.edit().putBoolean(key("notifications"),args.optBoolean("enabled")).commit();result.success("{}");};
                if(args.optBoolean("enabled")&&android.os.Build.VERSION.SDK_INT>=33)activity.permissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},save,e->result.error(runtime.failure(e)));else save.run();return;
            }
            if(command.equals("storage")){runtime.work(result,()->{long bytes=0;JSONArray drafts=store.drafts();for(int i=0;i<drafts.length();i++)bytes+=new File(drafts.getJSONObject(i).getString("path")).length();return new JSONObject().put("local_bytes",bytes).put("cache_bytes",cacheSize(new File(activity.getCacheDir(),"exports"))).toString();});return;}
            if(command.equals("import")||command.equals("photo")){runtime.signedIn();pick(command,args,result);return;}
            if(command.equals("pending_imports")){JSONArray list=pending(),safe=new JSONArray();for(int i=0;i<list.length();i++){JSONObject v=list.getJSONObject(i);safe.put(new JSONObject().put("id",v.getString("id")).put("title",v.getString("title")).put("size",v.getLong("size")));}result.success(new JSONObject().put("items",safe).put("error",prefs.getString("incoming_error","")).toString());return;}
            if(command.equals("accept_imports")){runtime.signedIn();String owner=store.scope();runtime.work(result,()->acceptPending(owner));return;}
            if(command.equals("discard_imports")){runtime.work(result,()->{JSONArray p=pending();for(int i=0;i<p.length();i++)pendingFile(p.getJSONObject(i)).delete();prefs.edit().remove("incoming").remove("incoming_error").commit();return "{}";});return;}
            if(command.equals("calendar")){runtime.signedIn();activity.permissions(new String[]{Manifest.permission.READ_CALENDAR},()->runtime.work(result,this::calendar),e->result.error(runtime.failure(e)));return;}
            if(command.equals("history")){runtime.work(result,()->history(args));return;}
            if(command.equals("clear_cache")){runtime.media.releasePlayer();runtime.work(result,()->{File root=new File(activity.getCacheDir(),"exports");long count=clearCache(root);return new JSONObject().put("bytes",count).toString();});return;}
            if(command.equals("export")||command.equals("preview")){runtime.signedIn();String owner=store.scope();runtime.work(launchResult(result,owner,command.equals("preview")),()->download(args,owner));return;}
            if(command.equals("local_export")){runtime.signedIn();String owner=store.scope();runtime.work(launchResult(result,owner,false),()->{
                JSONObject d=runtime.local(args.getString("id"));File source=new File(d.getString("path"));String ext=extension(source.getName());File folder=new File(activity.getCacheDir(),"exports/"+owner);folder.mkdirs();File out=new File(folder,UUID.randomUUID()+"."+ext);Files.copy(source.toPath(),out.toPath());return new JSONObject().put("file",out.getAbsolutePath()).put("format",ext).toString();});return;}
            throw new IOException("Unsupported Android action.");
        }catch(Exception e){result.error(runtime.failure(e));}
    }
    private JSONArray pending()throws JSONException{return new JSONArray(prefs.getString("incoming","[]"));}
    private File pendingFile(JSONObject item)throws Exception{
        String id=item.getString("id"),ext=extension(item.getString("title"));
        if(!id.matches("[a-f0-9-]{36}"))throw new IOException("Invalid pending import.");
        return new File(new File(activity.getFilesDir(),"incoming"),id+"."+ext);
    }
    boolean acceptIntent(Intent intent){
        String action=intent.getAction();if(!Intent.ACTION_SEND.equals(action)&&!Intent.ACTION_SEND_MULTIPLE.equals(action))return false;
        ArrayList<Uri> uris=new ArrayList<>();
        if(Intent.ACTION_SEND_MULTIPLE.equals(action)){ArrayList<Uri> values=intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);if(values!=null)uris.addAll(values);}
        else {Uri value=intent.getParcelableExtra(Intent.EXTRA_STREAM);if(value!=null)uris.add(value);}
        if(intent.getClipData()!=null)for(int i=0;i<intent.getClipData().getItemCount();i++){Uri u=intent.getClipData().getItemAt(i).getUri();if(u!=null&&!uris.contains(u))uris.add(u);}
        boolean fromHistory=(intent.getFlags()&Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)!=0;
        intent.setAction(null);intent.removeExtra(Intent.EXTRA_STREAM);
        runtime.io.execute(()->{
            try{
                if(uris.isEmpty())throw new IOException("The shared item does not contain a file.");
                String batch=hex(java.security.MessageDigest.getInstance("SHA-256").digest(uris.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8)));
                if(fromHistory&&batch.equals(prefs.getString("last_share",""))&&prefs.getBoolean("last_share_accepted",false)){runtime.main.post(()->runtime.openPersonal("imports"));return;}
                JSONArray values=pending();if(uris.size()>20)throw new IOException("Share up to 20 files at a time.");
                for(Uri uri:new LinkedHashSet<>(uris)){
                    JSONObject item=stage(uri);boolean duplicate=false;
                    for(int i=0;i<values.length();i++)if(item.optString("fingerprint").equals(values.getJSONObject(i).optString("fingerprint")))duplicate=true;
                    if(duplicate)pendingFile(item).delete();else values.put(item);
                    prefs.edit().putString("incoming",values.toString()).commit();
                }
                prefs.edit().putString("last_share",batch).putBoolean("last_share_accepted",false).remove("incoming_error").commit();
                runtime.main.post(()->runtime.openPersonal("imports"));
            }catch(Exception e){prefs.edit().putString("incoming_error",e.getMessage()).commit();runtime.main.post(()->runtime.openPersonal("imports"));}
        });return true;
    }
    private JSONObject stage(Uri uri)throws Exception{
        if(!"content".equals(uri.getScheme()))throw new IOException("Choose a file shared with read permission.");
        String name="Imported file";
        try(Cursor c=activity.getContentResolver().query(uri,new String[]{OpenableColumns.DISPLAY_NAME},null,null,null)){if(c!=null&&c.moveToFirst())name=c.getString(0);}
        name=new File(name.replace('\\','/')).getName();if(name.length()>250)name=name.substring(name.length()-250);
        String ext=extension(name);long maximum=limit(ext);String id=UUID.randomUUID().toString();
        File directory=new File(activity.getFilesDir(),"incoming");directory.mkdirs();File file=new File(directory,id+"."+ext);boolean done=false;long size=0;
        java.security.MessageDigest digest=java.security.MessageDigest.getInstance("SHA-256");
        try{
            try(InputStream in=activity.getContentResolver().openInputStream(uri);FileOutputStream out=new FileOutputStream(file)){
                if(in==null)throw new IOException("The shared file is unavailable.");byte[] data=new byte[65536];int n;
                while((n=in.read(data))!=-1){size+=n;if(size>maximum)throw new IOException("This file exceeds the import size limit.");digest.update(data,0,n);out.write(data,0,n);}out.getFD().sync();
            }
            if(size==0)throw new IOException("The selected file is empty.");done=true;
            return new JSONObject().put("id",id).put("title",name).put("size",size).put("fingerprint",hex(digest.digest())+":"+name);
        }finally{if(!done)file.delete();}
    }
    private String acceptPending(String owner)throws Exception{
        JSONArray values=pending(),saved=new JSONArray(),remaining=new JSONArray();
        for(int i=0;i<values.length();i++){
            JSONObject item=values.getJSONObject(i);
            try{saved.put(saveStaged(item,owner,new JSONObject()));pendingFile(item).delete();}
            catch(Exception e){remaining.put(item);for(int j=i+1;j<values.length();j++)remaining.put(values.get(j));prefs.edit().putString("incoming",remaining.toString()).commit();throw e;}
            for(int j=i+1;j<values.length();j++)remaining.put(values.get(j));prefs.edit().putString("incoming",remaining.toString()).commit();remaining=new JSONArray();
        }
        prefs.edit().remove("incoming_error").putBoolean("last_share_accepted",true).commit();return new JSONObject().put("items",saved).toString();
    }
    private static String hex(byte[] bytes){StringBuilder value=new StringBuilder();for(byte b:bytes)value.append(String.format(Locale.ROOT,"%02x",b));return value.toString();}
    void processingRetry(String path,JSONObject answer)throws Exception{
        if(!path.endsWith("/retry"))return;
        String recording=answer.optString("recording_id"),file=path.startsWith("/api/v1/files/")?path.substring("/api/v1/files/".length(),path.length()-"/retry".length()):"";
        synchronized(Store.class){JSONArray drafts=store.drafts();for(int i=0;i<drafts.length();i++){
            JSONObject draft=drafts.getJSONObject(i);
            if(!recording.isEmpty()&&recording.equals(draft.optString("recording_id"))||!file.isEmpty()&&file.equals(draft.optString("file_id"))){
                draft.put("ready_notified",false).put("status","processing").remove("error");store.save(draft);
            }
        }}ProcessingJobService.schedule(activity);
    }
    private void applyImportQueue(String id)throws Exception{
        JSONObject draft=store.draft(id);if(draft.optBoolean("import_queue_applied"))return;
        UploadQueue.saved(activity,draft);
        synchronized(Store.class){draft=store.draft(id);draft.put("import_queue_applied",true);store.save(draft);}
    }
    private JSONObject saveStaged(JSONObject item,String owner,JSONObject args)throws Exception{
        if(!owner.equals(store.scope())||owner.isEmpty())throw new IOException("Account changed. Import the file again.");
        String title=item.getString("title"),ext=extension(title);File staged=pendingFile(item);
        if(ext.equals("ics")){
            JSONObject result=runtime.api.upload("/api/v1/events/import.ics",staged,item.getString("title"),null,null);
            return new JSONObject().put("type","calendar").put("title",item.getString("title")).put("count",result.optJSONArray("created_ids")==null?0:result.getJSONArray("created_ids").length());
        }
        String id=item.getString("id");
        if(new File(store.folder(),id+".json").isFile()){
            JSONObject existing=store.draft(id);if(!new File(existing.getString("path")).isFile())throw new IOException("The local copy is missing. Import the file again.");
            applyImportQueue(id);return new JSONObject().put("id",id).put("type","local").put("title",existing.optString("title"));
        }
        JSONObject draft=store.newDraft(title,"."+ext).put("source","import").put("id",id).put("path",new File(store.folder(),id+"."+ext).getAbsolutePath());File file=new File(draft.getString("path"));boolean done=false;
        try{
            Files.copy(staged.toPath(),file.toPath(),java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            try(RandomAccessFile complete=new RandomAccessFile(file,"rw")){complete.getFD().sync();}
            if(MEDIA.contains(ext)){
                MediaMetadataRetriever reader=new MediaMetadataRetriever();long duration;
                try{reader.setDataSource(file.getAbsolutePath());String hasAudio=reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO);if(!"yes".equals(hasAudio))throw new IOException("This file has no supported audio track.");duration=Long.parseLong(reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));}finally{reader.release();}
                if(duration<100||duration>7200000L)throw new IOException("Choose audio or video up to 120 minutes.");draft.put("duration_ms",duration);
            }else{
                draft.put("kind","file").put("duration_ms",0).put("size",file.length());
                if(Arrays.asList("png","jpg","jpeg").contains(ext)){BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeFile(file.getAbsolutePath(),options);if(options.outWidth<=0||options.outHeight<=0||(long)options.outWidth*options.outHeight>25000000L)throw new IOException("Choose a valid image up to 25 megapixels.");}
                if(args.has("recording_id"))draft.put("recording_id_parent",args.getString("recording_id"));
                if(args.has("local_id"))draft.put("parent_local_id",args.getString("local_id"));
                if(args.has("at_ms"))draft.put("at_ms",args.getLong("at_ms"));
            }
            if(!owner.equals(store.scope()))throw new IOException("Account changed during import.");store.save(draft);done=true;applyImportQueue(id);
            return new JSONObject().put("id",draft.getString("id")).put("type","local").put("title",title);
        }finally{if(!done)file.delete();}
    }
    private void pick(String command,JSONObject args,Result<String> result)throws Exception{
        if(pickerResult!=null)throw new IOException("Finish the current import first.");pickerResult=result;pickerArgs=args;pickerOwner=store.scope();
        try{
            if(command.equals("photo")){
                File folder=new File(activity.getCacheDir(),"exports");folder.mkdirs();cameraFile=new File(folder,"photo-"+UUID.randomUUID()+".jpg");
                Uri uri=FileProvider.getUriForFile(activity,activity.getPackageName()+".exports",cameraFile);
                Intent intent=new Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                activity.startActivityForResult(intent,721);return;
            }
            boolean photos=args.optString("source").equals("photos");Intent intent;
            if(photos&&android.os.Build.VERSION.SDK_INT>=33){
                intent=new Intent(MediaStore.ACTION_PICK_IMAGES).putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX,Math.min(20,MediaStore.getPickImagesMaxLimit()));
            }else{
                intent=new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*").putExtra(Intent.EXTRA_ALLOW_MULTIPLE,true);
                intent.putExtra(Intent.EXTRA_MIME_TYPES,photos?new String[]{"image/png","image/jpeg","video/*"}:new String[]{"audio/*","video/*","image/png","image/jpeg","application/pdf","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/vnd.openxmlformats-officedocument.presentationml.presentation","application/vnd.ms-outlook","text/*"});
            }
            activity.startActivityForResult(intent,720);
        }catch(Exception e){pickerResult=null;throw e;}
    }
    boolean activityResult(int request,int result,Intent data){
        if(request==722){
            authenticating=false;boolean ok=result==Activity.RESULT_OK;
            if(ok){unlocked=true;unlockedScope=store.scope();if(enablingLock)prefs.edit().putBoolean(key("lock"),true).commit();hideLock();}
            if(authResult!=null){Result<String> callback=authResult;authResult=null;if(ok)callback.success("{}");else callback.error(runtime.failure(new IOException("Unlock was cancelled.")));}enablingLock=false;return true;
        }
        if(request!=720&&request!=721)return false;
        Result<String> callback=pickerResult;pickerResult=null;if(callback==null)return true;
        if(result!=Activity.RESULT_OK){callback.success("{\"items\":[]}");if(cameraFile!=null)cameraFile.delete();return true;}
        JSONObject args=pickerArgs;String owner=pickerOwner;
        runtime.work(callback,()->{
            ArrayList<Uri> uris=new ArrayList<>();
            if(request==721&&cameraFile!=null)uris.add(FileProvider.getUriForFile(activity,activity.getPackageName()+".exports",cameraFile));
            else if(data!=null){if(data.getClipData()!=null)for(int i=0;i<data.getClipData().getItemCount();i++)uris.add(data.getClipData().getItemAt(i).getUri());else if(data.getData()!=null)uris.add(data.getData());}
            if(uris.size()>20)throw new IOException("Import up to 20 files at a time.");JSONArray saved=new JSONArray();
            for(Uri uri:new LinkedHashSet<>(uris)){JSONObject staged=stage(uri);try{saved.put(saveStaged(staged,owner,args));}finally{pendingFile(staged).delete();}}
            if(cameraFile!=null){cameraFile.delete();cameraFile=null;}return new JSONObject().put("items",saved).toString();
        });return true;
    }
    private String calendar()throws Exception{
        JSONArray events=new JSONArray();Uri.Builder uri=CalendarContract.Instances.CONTENT_URI.buildUpon();
        ContentUris.appendId(uri,System.currentTimeMillis()-86400000L);ContentUris.appendId(uri,System.currentTimeMillis()+30L*86400000L);
        try(Cursor c=activity.getContentResolver().query(uri.build(),new String[]{CalendarContract.Instances.EVENT_ID,CalendarContract.Instances.TITLE,CalendarContract.Instances.BEGIN,CalendarContract.Instances.END},null,null,CalendarContract.Instances.BEGIN+" ASC")){
            while(c!=null&&c.moveToNext()&&events.length()<200)events.put(new JSONObject().put("native_id",android.provider.Settings.Secure.getString(activity.getContentResolver(),android.provider.Settings.Secure.ANDROID_ID)+":"+c.getLong(0)+":"+c.getLong(2)).put("title",c.getString(1)).put("starts_at",Instant.ofEpochMilli(c.getLong(2)).toString()).put("ends_at",Instant.ofEpochMilli(c.getLong(3)).toString()));
        }return new JSONObject().put("events",events).toString();
    }
    private String history(JSONObject args)throws Exception{
        String key=key("searches");JSONArray old=new JSONArray(prefs.getString(key,"[]")),next=new JSONArray();String query=args.optString("query").trim();
        if(!args.optBoolean("clear")){if(!query.isEmpty())next.put(query);for(int i=0;i<old.length()&&next.length()<10;i++)if(!old.getString(i).equals(query))next.put(old.getString(i));}
        prefs.edit().putString(key,next.toString()).commit();return new JSONObject().put("items",next).toString();
    }
    private long cacheSize(File file){if(file.isFile())return file.length();long size=0;File[] children=file.listFiles();if(children!=null)for(File c:children)size+=cacheSize(c);return size;}
    private long clearCache(File file){long total=0;File[] children=file.listFiles();if(children!=null)for(File child:children)total+=clearCache(child);if(file.isFile()){total=file.length();file.delete();}else file.delete();return total;}
    private String download(JSONObject args,String owner)throws Exception{
        String path=args.getString("path"),format=args.optString("format","txt");
        if(!path.startsWith("/api/v1/")||path.contains("..")||!format.matches("[a-z0-9]{1,8}"))throw new IOException("Invalid export request.");
        File folder=new File(activity.getCacheDir(),"exports/"+owner);folder.mkdirs();File out=new File(folder,UUID.randomUUID()+"."+format);runtime.api.download(path,out);
        if(!owner.equals(store.scope())){out.delete();throw new IOException("Account changed during export.");}
        return new JSONObject().put("file",out.getAbsolutePath()).put("format",format).toString();
    }
    private Result<String> launchResult(Result<String> result,String owner,boolean preview){return new Result<String>(){
      public void error(Throwable e){result.error(e);}
      public void success(String value){try{
        if(!owner.equals(store.scope()))throw new IOException("Account changed during export.");
        JSONObject data=new JSONObject(value);File out=new File(data.getString("file"));String format=data.getString("format");
        Uri uri=FileProvider.getUriForFile(activity,activity.getPackageName()+".exports",out);
        String mime=format.equals("pdf")?"application/pdf":format.equals("docx")?"application/vnd.openxmlformats-officedocument.wordprocessingml.document":format.equals("mp3")?"audio/mpeg":format.equals("wav")?"audio/wav":format.equals("png")?"image/png":format.equals("jpg")?"image/jpeg":format.equals("json")?"application/json":"text/plain";
        Intent intent=new Intent(preview?Intent.ACTION_VIEW:Intent.ACTION_SEND).setDataAndType(preview?uri:null,mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);if(!preview)intent.putExtra(Intent.EXTRA_STREAM,uri);activity.startActivity(Intent.createChooser(intent,preview?"Open file":"Export from Teno"));result.success("{}");
      }catch(Exception e){result.error(runtime.failure(e));}}
    };}
    private void startDictation(Result<String> result){
        try{
            if(voice!=null||RecorderService.active||RecorderService.finishing)throw new IOException("Finish phone recording before using voice input.");
            String owner=store.scope();File folder=new File(activity.getCacheDir(),"exports");folder.mkdirs();voiceFile=new File(folder,"question-"+UUID.randomUUID()+".m4a");
            voice=new MediaRecorder();voice.setAudioSource(MediaRecorder.AudioSource.MIC);voice.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);voice.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);voice.setAudioChannels(1);voice.setAudioSamplingRate(16000);voice.setAudioEncodingBitRate(64000);voice.setMaxDuration(60000);voice.setOutputFile(voiceFile.getAbsolutePath());voice.prepare();voice.start();
            voiceDialog=new AlertDialog.Builder(activity).setTitle("Speak your question").setMessage("Up to 60 seconds. You can edit the text before sending.").setCancelable(false).setPositiveButton("Stop",(d,w)->finishDictation(result,owner,true)).setNegativeButton("Cancel",(d,w)->finishDictation(result,owner,false)).create();voiceDialog.show();
            voice.setOnInfoListener((r,what,extra)->{if(what==MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED){if(voiceDialog!=null)voiceDialog.dismiss();finishDictation(result,owner,true);}});
        }catch(Exception e){releaseVoice();result.error(runtime.failure(e));}
    }
    private void finishDictation(Result<String> result,String owner,boolean save){
        if(voice==null)return;File file=voiceFile;boolean usable=true;try{voice.stop();}catch(RuntimeException e){usable=file.isFile()&&file.length()>100;}voice.release();voice=null;voiceFile=null;voiceDialog=null;
        if(!save||!usable){file.delete();result.success("{\"text\":\"\"}");return;}
        runtime.work(result,()->{try{if(!owner.equals(store.scope()))throw new IOException("Account changed during voice input.");JSONObject value=runtime.api.upload("/api/v1/personal/dictation",file,"question.m4a",null,null);if(!owner.equals(store.scope()))throw new IOException("Account changed during voice input.");return value.toString();}finally{file.delete();}});
    }
    private void releaseVoice(){if(voiceDialog!=null)voiceDialog.dismiss();voiceDialog=null;if(voice!=null){try{voice.stop();}catch(Exception ignored){}voice.release();voice=null;}if(voiceFile!=null)voiceFile.delete();voiceFile=null;}
    void close(){releaseVoice();}
    void pause(){pausedAt=SystemClock.elapsedRealtime();}
    void resume(){
        boolean enabled=prefs.getBoolean(key("lock"),false);
        if(enabled&&(!unlocked||!unlockedScope.equals(store.scope())||pausedAt>0&&SystemClock.elapsedRealtime()-pausedAt>60000)){showLock();authenticate();}
        if(enabled)activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
    }
    private void setLock(boolean enabled,Result<String> result)throws Exception{
        if(!enabled){prefs.edit().putBoolean(key("lock"),false).commit();hideLock();activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);result.success("{}");return;}
        KeyguardManager manager=(KeyguardManager)activity.getSystemService(Context.KEYGUARD_SERVICE);
        if(!manager.isDeviceSecure())throw new IOException("Set a screen lock in Android Settings before enabling App lock.");
        authResult=result;enablingLock=true;authenticate();
    }
    private void authenticate(){
        if(authenticating)return;KeyguardManager manager=(KeyguardManager)activity.getSystemService(Context.KEYGUARD_SERVICE);
        Intent intent=manager.createConfirmDeviceCredentialIntent("Unlock Teno","Use your phone's screen lock to continue.");
        if(intent!=null){authenticating=true;activity.startActivityForResult(intent,722);}
    }
    private void showLock(){
        if(lockCover!=null)return;LinearLayout cover=new LinearLayout(activity);cover.setOrientation(LinearLayout.VERTICAL);cover.setGravity(Gravity.CENTER);cover.setBackgroundColor(0xfff8f9f9);
        TextView title=new TextView(activity);title.setText("Teno is locked");title.setTextSize(26);cover.addView(title);
        Button button=new Button(activity);button.setText("Unlock");button.setOnClickListener(v->authenticate());cover.addView(button);
        cover.setClickable(true);lockCover=cover;activity.addContentView(cover,new ViewGroup.LayoutParams(-1,-1));
    }
    private void hideLock(){if(lockCover!=null){((ViewGroup)lockCover.getParent()).removeView(lockCover);lockCover=null;}}
}
