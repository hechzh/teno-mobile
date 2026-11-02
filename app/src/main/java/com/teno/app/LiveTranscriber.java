package com.teno.app;

import org.json.*;
import okhttp3.*;
import okio.ByteString;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

/** Authenticated PCM streaming. Azure subscription credentials stay on the server. */
public final class LiveTranscriber {
    private final Store store;private final Api api;private final String title,language,draftId;
    private final ScheduledExecutorService executor=Executors.newSingleThreadScheduledExecutor();
    private final OkHttpClient client=new OkHttpClient.Builder().connectTimeout(15,TimeUnit.SECONDS).readTimeout(0,TimeUnit.MILLISECONDS).pingInterval(10,TimeUnit.SECONDS).build();
    private final ArrayList<JSONObject> segments=new ArrayList<>();private final HashSet<String> seen=new HashSet<>();
    private final ByteArrayOutputStream queued=new ByteArrayOutputStream();private final CountDownLatch finished=new CountDownLatch(1);
    private WebSocket socket;private int generation=0,retries=0;private long bytes=0,baseOffset=0;
    private ScheduledFuture<?> retryTask;
    private boolean ready=false,stopping=false,closed=false,paused=false,retryScheduled=false,complete=false;
    public volatile String status="Connecting",partial="",sessionId="";
    public volatile boolean gap=false;
    LiveTranscriber(Store s,String id,String name,String locale){store=s;api=new Api(s);draftId=id;title=name;language="auto";connect();}
    public synchronized JSONArray segments(){JSONArray result=new JSONArray();for(JSONObject s:segments)result.put(s);return result;}
    public synchronized long audioMillis(){return bytes/32;}
    private synchronized void connect(){
        if(closed||stopping||ready)return;int attempt=++generation;ready=false;retryScheduled=false;status=retries==0?"Connecting":"Reconnecting";baseOffset=bytes/32;queued.reset();
        executor.execute(()->{try{
            JSONObject body=new JSONObject().put("title",title).put("language",language).put("client_id",draftId+"-"+UUID.randomUUID().toString().substring(0,12)).put("preview",true).put("recording_client_id",draftId);
            JSONObject session=api.post("/api/v1/realtime/sessions",body);
            synchronized(this){if(closed||stopping||attempt!=generation)return;sessionId=session.getString("id");}
            String route=session.getString("websocket_path");if(!route.startsWith("/api/v1/realtime/sessions/")||route.contains(".."))throw new IOException("Invalid live session address");
            Request request=new Request.Builder().url(store.base().replaceFirst("^https:","wss:").replaceFirst("^http:","ws:")+route).header("Authorization","Bearer "+store.token("access_token")).build();
            WebSocket ws=client.newWebSocket(request,new WebSocketListener(){
                @Override public void onMessage(WebSocket ws,String text){handle(attempt,ws,text);}
                @Override public void onFailure(WebSocket ws,Throwable t,Response response){failed(attempt,"Connection lost");}
                @Override public void onClosed(WebSocket ws,int code,String reason){synchronized(LiveTranscriber.this){if(attempt!=generation||complete||closed)return;}failed(attempt,"Live transcription stopped");}
            });
            synchronized(this){if(attempt==generation&&!closed)socket=ws;else ws.cancel();}
        }catch(Exception e){failed(attempt,e instanceof Api.Failure&&((Api.Failure)e).status==401?"Sign in to resume live transcription":"Connection unavailable");}});
    }
    private synchronized void handle(int attempt,WebSocket ws,String text){
        if(attempt!=generation||closed)return;
        try{JSONObject event=new JSONObject(text);switch(event.optString("type")){
            case "ready":socket=ws;ready=true;retries=0;status=paused?"Paused":gap?"Live · transcript has gaps":"Live";
                byte[] pending=queued.toByteArray();queued.reset();for(int n=0;n<pending.length;n+=16000)if(!ws.send(ByteString.of(pending,n,Math.min(16000,pending.length-n)))){failed(attempt,"Connection lost");return;}
                if(paused)ws.send("{\"type\":\"pause\"}");break;
            case "partial":if(!paused&&!stopping)partial=event.optString("text");break;
            case "final":if(seen.add(event.optString("id"))){event.put("start_ms",event.optLong("start_ms")+baseOffset).put("end_ms",event.optLong("end_ms")+baseOffset);segments.add(event);}partial="";break;
            case "completed":complete=true;ready=false;partial="";status=gap?"Transcript incomplete":"Transcript complete";finished.countDown();break;
            case "interrupted":failed(attempt,"Transcript incomplete");break;
            case "error":failed(attempt,event.optString("code").equals("ASR_BUSY")?"Transcription service busy":"Live transcription unavailable");break;
        }}catch(Exception e){failed(attempt,"Invalid transcription response");}
    }
    private synchronized void failed(int attempt,String reason){
        if(attempt!=generation||closed||complete||retryScheduled)return;ready=false;gap=true;partial="";status=reason;queued.reset();if(socket!=null){socket.cancel();socket=null;}
        if(stopping){finished.countDown();return;}
        if(!retryScheduled){retryScheduled=true;retries++;retryTask=executor.schedule(this::connect,reason.contains("busy")?30:Math.min(30,3*retries),TimeUnit.SECONDS);}
    }
    public synchronized void feed(byte[] pcm,int count){
        if(closed||stopping||paused||count==0)return;bytes+=count;
        if(ready&&socket!=null){if(socket.queueSize()>320000||!socket.send(ByteString.of(pcm,0,count)))failed(generation,"Connection too slow");}
        else if(!retryScheduled){if(queued.size()+count<=320000)queued.write(pcm,0,count);else{gap=true;queued.reset();baseOffset=bytes/32;}}
        else gap=true;
    }
    public synchronized void pause(boolean value){paused=value;partial="";status=value?"Paused":ready?(gap?"Live · transcript has gaps":"Live"):"Connecting";if(ready&&socket!=null)socket.send(value?"{\"type\":\"pause\"}":"{\"type\":\"resume\"}");}
    public synchronized void retry(){if(!closed&&!stopping&&!ready){if(retryTask!=null)retryTask.cancel(false);generation++;if(socket!=null)socket.cancel();connect();}}
    /** Called off the UI thread after the last local PCM frame has been saved. */
    public String finish(){
        synchronized(this){stopping=true;status="Finishing transcript";partial="";if(ready&&socket!=null)socket.send("{\"type\":\"stop\"}");else finished.countDown();}
        try{finished.await(22,TimeUnit.SECONDS);}catch(InterruptedException e){Thread.currentThread().interrupt();}
        synchronized(this){String reusable=complete&&!gap?sessionId:"";if(!complete){gap=true;status="Transcript incomplete";}close();return reusable;}
    }
    public synchronized void close(){if(closed)return;closed=true;ready=false;generation++;if(socket!=null){if(complete)socket.close(1000,"Saved");else socket.cancel();}finished.countDown();executor.shutdownNow();client.dispatcher().executorService().shutdown();client.connectionPool().evictAll();}
}
