package com.teno.app;

import android.app.*;
import android.content.*;
import android.media.*;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.view.WindowManager;
import androidx.core.content.FileProvider;
import org.json.*;
import java.io.*;
import java.util.*;
import static com.teno.app.RuntimeMessages.*;

/** System pickers/sharing and playback, independent of Flutter widget lifetimes. */
final class NativeMedia {
    private final NativeRuntime runtime;
    private final MainActivity activity;
    private final Store store;
    private final Api api;
    private MediaPlayer player;
    private boolean ready,keyPending;
    private String mediaId="",error="",keyAddress="";
    private double speed=1;
    private long generation;
    private NullableResult<String> pickerResult;
    NativeMedia(NativeRuntime runtime){this.runtime=runtime;activity=runtime.activity;store=runtime.store;api=runtime.api;}
    PlaybackState state(){
        return new PlaybackState.Builder().setReady(ready).setPlaying(ready&&player!=null&&player.isPlaying())
            .setPositionMs(ready&&player!=null?(long)player.getCurrentPosition():0L)
            .setDurationMs(ready&&player!=null?(long)player.getDuration():0L).setSpeed(speed).setMediaId(mediaId).setError(error).build();
    }
    void showDeviceKey(VoidResult result){runtime.ui(result,()->{
        if(keyPending)throw new IOException("Finish the current device key request.");
        KeyguardManager manager=(KeyguardManager)activity.getSystemService(Context.KEYGUARD_SERVICE);
        if(!manager.isDeviceSecure())throw new IOException("Set a phone screen lock before viewing a device key.");
        keyAddress=runtime.device().optString("address",store.recorderAddress());
        if(store.deviceKey(keyAddress).isEmpty())throw new IOException("No device key is saved.");
        Intent prompt=manager.createConfirmDeviceCredentialIntent(UiLocale.text(activity,"Teno device key"),UiLocale.text(activity,"Unlock to view your recorder's binding key."));
        if(prompt==null)throw new IOException("Screen-lock verification is unavailable.");
        keyPending=true;activity.startActivityForResult(prompt,512);
    });}
    void importAudio(NullableResult<String> result){
        if(pickerResult!=null){result.error(runtime.failure(new IOException("Finish the current import first.")));return;}
        try{runtime.signedIn();pickerResult=result;Intent pick=new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*");
            pick.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"audio/*","video/mp4","application/ogg"});activity.startActivityForResult(pick,511);
        }catch(Exception e){pickerResult=null;result.error(runtime.failure(e));}
    }
    void activityResult(int request,int result,Intent data){
        if(request==512&&keyPending){keyPending=false;if(result!=Activity.RESULT_OK)return;
            try{
                String secret=store.deviceKey(keyAddress);activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                AlertDialog dialog=new AlertDialog.Builder(activity).setTitle(UiLocale.text(activity,"Device key backup")).setMessage(secret+"\n\n"+UiLocale.text(activity,"Keep this key private. It is needed to connect this recorder from another phone."))
                    .setPositiveButton(UiLocale.text(activity,"Done"),null).create();
                dialog.setOnDismissListener(x->activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE));dialog.show();
            }catch(Exception ignored){}return;
        }
        if(request!=511||pickerResult==null)return;
        NullableResult<String> callback=pickerResult;pickerResult=null;
        if(result!=Activity.RESULT_OK||data==null||data.getData()==null){callback.success(null);return;}
        Uri uri=data.getData();String owner=store.scope();
        runtime.work(new Result<String>(){public void success(String id){callback.success(id);}public void error(Throwable e){callback.error(e);}},()->{
            String name="Imported audio.wav";
            try(android.database.Cursor cursor=activity.getContentResolver().query(uri,new String[]{OpenableColumns.DISPLAY_NAME},null,null,null)){if(cursor!=null&&cursor.moveToFirst())name=cursor.getString(0);}
            String ext=name.contains(".")?name.substring(name.lastIndexOf('.')).toLowerCase(Locale.ROOT):".wav";
            if(!Arrays.asList(".wav",".mp3",".m4a",".ogg",".mp4").contains(ext))throw new IOException("Supported formats: WAV, MP3, M4A, MP4 and OGG.");
            JSONObject draft=store.newDraft(name,ext);File file=new File(draft.getString("path"));boolean kept=false;
            try{
                try(InputStream in=activity.getContentResolver().openInputStream(uri);FileOutputStream out=new FileOutputStream(file)){
                    if(in==null)throw new IOException("The selected file is unavailable.");byte[] buffer=new byte[65536];long total=0;int n;
                    while((n=in.read(buffer))!=-1){total+=n;if(total>262144000)throw new IOException("The import limit is 250 MiB.");out.write(buffer,0,n);}out.getFD().sync();
                }
                MediaMetadataRetriever reader=new MediaMetadataRetriever();long duration;
                try{reader.setDataSource(file.getAbsolutePath());duration=Long.parseLong(reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));}finally{reader.release();}
                if(duration<100||duration>7200000)throw new IOException("Choose playable audio up to 120 minutes.");
                if(!owner.equals(store.scope()))throw new IOException("Account changed. Import the file again.");
                draft.put("duration_ms",duration);store.save(draft);kept=true;UploadQueue.saved(activity,draft);return draft.getString("id");
            }finally{if(!kept)file.delete();}
        });
    }
    void playback(PlaybackAction action,String id,boolean local,long position,double rate,VoidResult result){
        try{
            if(action==PlaybackAction.STOP){releasePlayer();result.success();return;}
            if(action==PlaybackAction.SPEED){
                if(rate<0.5||rate>2.0)throw new IOException("Unsupported playback speed.");
                speed=rate;if(ready)player.setPlaybackParams(player.getPlaybackParams().setSpeed((float)rate));result.success();return;
            }
            if(ready&&mediaId.equals(id)){
                if(action==PlaybackAction.PAUSE)player.pause();
                else if(action==PlaybackAction.SEEK)player.seekTo((int)position);
                else{if(position>0)player.seekTo((int)position);player.start();}
                result.success();return;
            }
            if(action==PlaybackAction.PAUSE||action==PlaybackAction.SEEK){result.success();return;}
            runtime.signedIn();releasePlayer();error="";mediaId=id;long request=++generation;String owner=store.scope();
            runtime.work(new Result<File>(){
                public void error(Throwable e){error=e.getMessage()==null?"Audio unavailable":e.getMessage();result.error(e);}
                public void success(File file){
                    if(request!=generation||!owner.equals(store.scope())){result.error(runtime.failure(new IOException("Playback request changed.")));return;}
                    try{
                        player=new MediaPlayer();player.setDataSource(file.getAbsolutePath());
                        player.setOnPreparedListener(p->{ready=true;p.seekTo((int)position);p.setPlaybackParams(new PlaybackParams().setSpeed((float)speed));p.start();});
                        player.setOnErrorListener((p,what,extra)->{error="This audio could not be played.";ready=false;p.reset();return true;});
                        player.prepareAsync();result.success();
                    }catch(Exception e){result.error(runtime.failure(e));}
                }
            },()->{
                if(local)return new File(runtime.local(id).getString("path"));
                if(!id.matches("[A-Za-z0-9_-]{1,128}"))throw new IOException("Invalid recording.");
                JSONArray drafts=store.drafts();for(int i=0;i<drafts.length();i++){JSONObject d=drafts.getJSONObject(i);if(id.equals(d.optString("recording_id"))&&new File(d.optString("path")).isFile())return new File(d.getString("path"));}
                File folder=new File(activity.getCacheDir(),"audio/"+owner);folder.mkdirs();File file=new File(folder,id+".wav");
                if(!file.isFile())api.download("/api/v1/recordings/"+id+"/audio",file);return file;
            });
        }catch(Exception e){result.error(runtime.failure(e));}
    }
    void releaseIfPlaying(String id){if(mediaId.equals(id))releasePlayer();}
    void releasePlayer(){generation++;ready=false;if(player!=null){player.release();player=null;}mediaId="";}
    void shareExport(String id,String format,VoidResult result){
        String owner=store.scope();
        runtime.work(new Result<File>(){
            public void error(Throwable e){result.error(e);}
            public void success(File file){runtime.ui(result,()->{
                if(!owner.equals(store.scope()))throw new IOException("Account changed. Open the export again.");
                Uri uri=FileProvider.getUriForFile(activity,activity.getPackageName()+".exports",file);
                Intent send=new Intent(Intent.ACTION_SEND).setType(format.equals("audio")?"audio/wav":format.equals("json")?"application/json":"text/plain")
                    .putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                send.setClipData(ClipData.newRawUri("Teno export",uri));activity.startActivity(Intent.createChooser(send,UiLocale.text(activity,"Share from Teno")));
            });}
        },()->{
            runtime.signedIn();if(!id.matches("[A-Za-z0-9_-]{1,128}")||!Arrays.asList("txt","md","json","audio").contains(format))throw new IOException("Unsupported export.");
            File folder=new File(activity.getCacheDir(),"exports");folder.mkdirs();File file=new File(folder,"Teno-"+UUID.randomUUID()+"."+(format.equals("audio")?"wav":format));
            if(format.equals("audio")){api.download("/api/v1/recordings/"+id+"/audio",file);return file;}
            try(FileOutputStream out=new FileOutputStream(file)){out.write(api.bytes("GET","/api/v1/recordings/"+id+"/exports?format="+format,null));}return file;
        });
    }
}
