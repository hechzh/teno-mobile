package com.teno.app;

import android.content.Context;
import android.content.ContextWrapper;
import android.content.SharedPreferences;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;

/** Real Android HTTP and encrypted storage, isolated preferences and synthetic loopback only. */
final class LoginErrorChecks {
    private static final String INVALID="Invalid username or password. Check your Teno account and try again.";
    private volatile String mode="invalid";
    private volatile boolean passwordIntact;
    private final AtomicInteger refreshes=new AtomicInteger();
    private final ServerSocket server;
    private LoginErrorChecks()throws Exception{server=new ServerSocket(0,8,InetAddress.getByName("127.0.0.1"));}
    static void run(RuntimeInstrumentation test,Context original)throws Exception{
        new LoginErrorChecks().check(test,original);
    }
    private void check(RuntimeInstrumentation test,Context original)throws Exception{
        Context isolated=new ContextWrapper(original){
            @Override public Context getApplicationContext(){return this;}
            @Override public SharedPreferences getSharedPreferences(String name,int flags){return original.getSharedPreferences("auth-errors-"+name,flags);}
        };
        Store store=new Store(isolated);Api api=new Api(store);
        Thread worker=new Thread(()->{while(!server.isClosed())try{serve(server.accept());}catch(Exception ignored){}});
        worker.setDaemon(true);worker.start();
        try{
            store.base("http://127.0.0.1:"+server.getLocalPort());
            for(String value:new String[]{"invalid","empty"}){
                mode=value;
                try{api.login("synthetic","incorrect");throw new AssertionError("Rejected login accepted");}
                catch(Api.Failure e){test.check(e.status==401&&e.code.equals("INVALID_CREDENTIALS")&&e.getMessage().equals(INVALID),value+"_login_401_is_credentials_not_expiry");}
            }
            test.check(refreshes.get()==0,"failed_login_does_not_refresh_old_session");
            mode="rate";
            try{api.login("synthetic","incorrect");throw new AssertionError("Rate limit ignored");}
            catch(Api.Failure e){test.check(e.status==429&&e.code.equals("RATE_LIMITED"),"login_rate_limit_keeps_its_classification");}
            mode="success";api.login("synthetic"," MiXeD中文.Paß! ");
            test.check(passwordIntact,"password_bytes_and_intentional_whitespace_are_preserved");
            test.check(!store.scope().isEmpty()&&store.name().equals("synthetic")&&store.token("access_token").equals("fresh"),"valid_login_sets_account_and_encrypted_tokens");
            mode="refresh-good";store.tokens(new JSONObject().put("access_token","expired").put("refresh_token","refresh"));
            test.check(api.get("/api/v1/me").getString("id").equals("synthetic-auth-user")&&refreshes.get()==1,"expired_access_token_refreshes_and_retries");
            mode="refresh-rejected";store.tokens(new JSONObject().put("access_token","expired").put("refresh_token","revoked"));
            try{api.get("/api/v1/me");throw new AssertionError("Revoked refresh accepted");}
            catch(Api.Failure e){test.check(e.status==401&&e.code.equals("UNAUTHORIZED")&&e.getMessage().equals("Your session expired. Sign in again."),"genuine_expiry_stays_distinct_from_bad_password");}
        }finally{server.close();worker.join(1000);}
        store.base("http://127.0.0.1:9");
        try{api.login("synthetic","incorrect");throw new AssertionError("Unavailable server accepted");}
        catch(Api.Failure e){throw new AssertionError("Transport incorrectly classified as authentication");}
        catch(IOException e){test.check(!e.getMessage().contains("session expired"),"network_failure_is_not_session_expiry");}
    }
    private void serve(Socket socket)throws Exception{
        try(Socket s=socket){
            s.setSoTimeout(5000);InputStream in=s.getInputStream();String request=line(in),header,authorization="";int length=0;
            while(!(header=line(in)).isEmpty()){
                if(header.toLowerCase(java.util.Locale.ROOT).startsWith("content-length:"))length=Integer.parseInt(header.substring(15).trim());
                if(header.toLowerCase(java.util.Locale.ROOT).startsWith("authorization:"))authorization=header.substring(14).trim();
            }
            byte[] bytes=in.readNBytes(length);JSONObject body=length==0?new JSONObject():new JSONObject(new String(bytes,StandardCharsets.UTF_8));
            String path=request.split(" ")[1];int status=200;JSONObject result=new JSONObject();
            if(path.equals("/api/v1/auth/login")){
                if(mode.equals("invalid")){status=401;result.put("code","INVALID_CREDENTIALS").put("message","Invalid username or password");}
                else if(mode.equals("empty")){status=401;}
                else if(mode.equals("rate")){status=429;result.put("code","RATE_LIMITED").put("message","Try later");}
                else{passwordIntact=body.optString("password").equals(" MiXeD中文.Paß! ");result.put("access_token","fresh").put("refresh_token","refresh");}
            }else if(path.equals("/api/v1/auth/refresh")){
                refreshes.incrementAndGet();
                if(mode.equals("refresh-rejected")){status=401;result.put("code","UNAUTHORIZED").put("message","Invalid refresh token");}
                else result.put("access_token","fresh").put("refresh_token","new-refresh");
            }else if(authorization.equals("Bearer expired")){status=401;result.put("code","UNAUTHORIZED").put("message","Login required");}
            else result.put("id","synthetic-auth-user").put("username","synthetic");
            byte[] data=result.toString().getBytes(StandardCharsets.UTF_8);OutputStream out=s.getOutputStream();
            out.write(("HTTP/1.1 "+status+" Result\r\nContent-Type: application/json\r\nContent-Length: "+data.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));out.write(data);out.flush();
        }
    }
    private static String line(InputStream in)throws IOException{
        ByteArrayOutputStream out=new ByteArrayOutputStream();int b;while((b=in.read())!=-1){if(b=='\n')break;if(b!='\r')out.write(b);}return out.toString(StandardCharsets.UTF_8.name());
    }
}
