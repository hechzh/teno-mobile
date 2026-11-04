package com.teno.app;

import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

public final class Api {
    public interface Progress {void update(long sent,long total);}
    private final Store store;
    private static final Object REFRESH_LOCK=new Object();
    private static final Object PREFERENCES_LOCK=new Object();
    public Api(Store s){store=s;}
    public static class Failure extends IOException{
        public final int status;public final String code;
        Failure(int s,String code,String message){super(message);status=s;this.code=code;}
    }
    public static String validateBase(String value)throws Exception{
        URI u=new URI(value.trim());String scheme=u.getScheme(),host=u.getHost();
        if(host==null||u.getUserInfo()!=null||u.getQuery()!=null||u.getFragment()!=null||!(u.getPath()==null||u.getPath().isEmpty()||u.getPath().equals("/")))throw new IOException("Enter a server address without a path or account details");
        if(!"https".equals(scheme)&&!("http".equals(scheme)&&(host.equals("127.0.0.1")||host.equals("10.0.2.2"))))throw new IOException("Use an HTTPS server address");
        return value.trim().replaceAll("/+$","");
    }
    private HttpURLConnection open(String path,String method,String token)throws Exception{
        HttpURLConnection c=(HttpURLConnection)new URL(store.base()+path).openConnection();c.setRequestMethod(method);c.setConnectTimeout(20000);c.setReadTimeout(90000);c.setInstanceFollowRedirects(false);
        c.setRequestProperty("Accept","application/json");c.setRequestProperty("Origin",store.base());if(!token.isEmpty())c.setRequestProperty("Authorization","Bearer "+token);return c;
    }
    private byte[] read(HttpURLConnection c)throws Exception{
        int status=c.getResponseCode();InputStream stream=status>=400?c.getErrorStream():c.getInputStream();byte[] bytes=stream==null?new byte[0]:readStream(stream);if(stream!=null)stream.close();
        if(status>=300){String code="HTTP_"+status,message="Request failed ("+status+")";
            try{JSONObject o=new JSONObject(new String(bytes,StandardCharsets.UTF_8));code=o.optString("code",code);message=o.optString("message",message);}catch(Exception ignored){}
            if(message.matches("(?s).*[\\p{IsHan}].*")){String[] parts=message.split(" / ");message="Request could not be completed ("+code+").";for(String p:parts)if(!p.matches("(?s).*[\\p{IsHan}].*"))message=p;}
            if(status==401)message="Your session expired. Sign in again.";
            throw new Failure(status,code,message);
        }return bytes;
    }
    private void refresh(String old)throws Exception{
        synchronized(REFRESH_LOCK){
            if(!store.token("access_token").equals(old))return;
            String token=store.token("refresh_token");if(token.isEmpty())throw new Failure(401,"UNAUTHORIZED","Please sign in again");
            HttpURLConnection c=open("/api/v1/auth/refresh","POST","");
            try{sendJson(c,new JSONObject().put("refresh_token",token));store.tokens(new JSONObject(new String(read(c),StandardCharsets.UTF_8)));}finally{c.disconnect();}
        }
    }
    private void sendJson(HttpURLConnection c,JSONObject data)throws Exception{
        c.setDoOutput(true);c.setRequestProperty("Content-Type","application/json");byte[] bytes=data.toString().getBytes(StandardCharsets.UTF_8);c.setFixedLengthStreamingMode(bytes.length);try(OutputStream out=c.getOutputStream()){out.write(bytes);}
    }
    public JSONObject request(String method,String path,JSONObject body)throws Exception{
        return new JSONObject(new String(bytes(method,path,body),StandardCharsets.UTF_8));
    }
    public JSONObject get(String path)throws Exception{return request("GET",path,null);}
    /** Stream large audio to disk; never buffer a complete recording in Java heap. */
    public void download(String path,File destination)throws Exception{
        for(int attempt=0;attempt<2;attempt++){
            String token=store.token("access_token");HttpURLConnection c=open(path,"GET",token);
            try{
                int status=c.getResponseCode();
                if(status>=300){read(c);return;}
                try(InputStream in=c.getInputStream();FileOutputStream out=new FileOutputStream(destination)){
                    byte[] buffer=new byte[65536];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);out.getFD().sync();
                }return;
            }catch(Failure e){destination.delete();if(e.status!=401||attempt>0)throw e;refresh(token);}
            catch(Exception e){destination.delete();throw e;}finally{c.disconnect();}
        }
    }
    public JSONObject post(String path,JSONObject body)throws Exception{return request("POST",path,body);}
    public byte[] bytes(String method,String path,JSONObject body)throws Exception{
        for(int attempt=0;attempt<2;attempt++){
            String token=store.token("access_token");HttpURLConnection c=open(path,method,token);
            try{if(body!=null)sendJson(c,body);return read(c);}catch(Failure e){if(e.status!=401||attempt>0||path.startsWith("/api/v1/auth/"))throw e;refresh(token);}finally{c.disconnect();}
        }throw new IOException("Request failed");
    }
    public void login(String username,String password)throws Exception{
        JSONObject tokens=post("/api/v1/auth/login",new JSONObject().put("username",username).put("password",password));store.tokens(tokens);
        JSONObject me=get("/api/v1/me");store.identity(username,me.getString("id"));
    }
    public void ensureNativePreferences()throws Exception{
        synchronized(PREFERENCES_LOCK){if(store.nativePreferencesSet()||store.scope().isEmpty())return;String scope=store.scope();JSONObject current=get("/api/v1/me").optJSONObject("settings");
            request("PATCH","/api/v1/me",new JSONObject().put("language",store.language()).put("summary_language","en-US").put("timezone",current==null?java.time.ZoneId.systemDefault().getId():current.optString("timezone",java.time.ZoneId.systemDefault().getId())));
            if(scope.equals(store.scope()))store.markNativePreferences();
        }
    }
    public JSONObject savePreferences(JSONObject body)throws Exception{
        synchronized(PREFERENCES_LOCK){JSONObject result=request("PATCH","/api/v1/me",body);store.markNativePreferences();return result;}
    }
    public JSONObject upload(String path,File file,String filename,JSONObject fields,Progress progress)throws Exception{
        for(int attempt=0;attempt<2;attempt++){
            String token=store.token("access_token"),boundary="Teno"+System.nanoTime();HttpURLConnection c=open(path,"POST",token);
            try{
                c.setDoOutput(true);c.setChunkedStreamingMode(65536);c.setRequestProperty("Content-Type","multipart/form-data; boundary="+boundary);
                try(OutputStream out=c.getOutputStream()){
                    if(fields!=null){java.util.Iterator<String> it=fields.keys();while(it.hasNext()){String k=it.next();write(out,"--"+boundary+"\r\nContent-Disposition: form-data; name=\""+k+"\"\r\n\r\n"+fields.getString(k)+"\r\n");}}
                    if(file!=null){write(out,"--"+boundary+"\r\nContent-Disposition: form-data; name=\"file\"; filename=\""+filename.replaceAll("[\"\r\n]","_")+"\"\r\nContent-Type: application/octet-stream\r\n\r\n");
                    try(InputStream in=new FileInputStream(file)){byte[] buffer=new byte[65536];long sent=0;int n;while((n=in.read(buffer))!=-1){out.write(buffer,0,n);sent+=n;if(progress!=null)progress.update(sent,file.length());}}}
                    write(out,"\r\n--"+boundary+"--\r\n");
                }
                return new JSONObject(new String(read(c),StandardCharsets.UTF_8));
            }catch(Failure e){if(e.status!=401||attempt>0)throw e;refresh(token);}finally{c.disconnect();}
        }throw new IOException("Upload failed");
    }
    private static void write(OutputStream out,String value)throws IOException{out.write(value.getBytes(StandardCharsets.UTF_8));}
    public static byte[] readStream(InputStream in)throws IOException{ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buf=new byte[32768];int n;while((n=in.read(buf))!=-1)out.write(buf,0,n);return out.toByteArray();}
    public static String query(String q){try{return URLEncoder.encode(q,"UTF-8");}catch(Exception e){throw new IllegalArgumentException(e);}}
}
