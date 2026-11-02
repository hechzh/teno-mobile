package com.teno.app;

import android.app.*;
import android.content.*;
import android.graphics.*;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/** Screenshot and text-glyph geometry checks. Loopback fixtures, isolated APK only. */
public final class NavigationInstrumentation extends Instrumentation {
    Context context; MainActivity personal; TeamActivity team; ServerSocket server;
    boolean expectedAligned; String runName; final JSONArray pages=new JSONArray();
    JSONObject json(Object... fields)throws Exception{JSONObject j=new JSONObject();for(int i=0;i<fields.length;i+=2)j.put((String)fields[i],fields[i+1]);return j;}
    @Override public void onCreate(Bundle args){super.onCreate(args);expectedAligned=!"false".equals(args.getString("aligned"));runName=args.getString("run","normal");start();}
    void ui(Runnable action)throws Exception{runOnMainSync(action);waitForIdleSync();Thread.sleep(150);}
    void ready(MainActivity a)throws Exception{long until=SystemClock.elapsedRealtime()+10000;while(a.loading||MainActivity.pendingOperations.get()>0){if(SystemClock.elapsedRealtime()>until)throw new IOException("Page load timed out");Thread.sleep(50);}waitForIdleSync();Thread.sleep(250);}
    JSONObject response(String path)throws Exception{
        JSONArray items=new JSONArray();String date="2026-11-01T09:00:00Z";
        if(path.startsWith("/api/v1/recordings"))items.put(json("id","demo-recording","title","Product review","status","transcribed","created_at",date,"duration_ms",1116000));
        else if(path.startsWith("/api/v1/chats"))items.put(json("id","demo-chat","created_at",date,"data",json("title","Product review questions","recording_ids",new JSONArray().put("demo-recording"))));
        else if(path.startsWith("/api/v1/tasks"))items.put(json("id","demo-task","data",json("title","Review the app screens","completed",false,"content","Check navigation labels and text size.")));
        else if(path.startsWith("/api/v1/teams/visual/meetings"))items.put(json("id","demo-meeting","title","Product review","title_en","Product review","started_at",date,"status","draft"));
        else if(path.startsWith("/api/v1/teams/visual/chats"))items.put(json("id","demo-chat","title","Release questions","created_at",date));
        else if(path.startsWith("/api/v1/teams/visual/tasks"))items.put(json("id","demo-task","title","Review the app screens","title_en","Review the app screens","status","review","assignee_name","Alex"));
        return json("items",items,"decisions",new JSONArray(),"opinions",new JSONArray(),"issues",new JSONArray());
    }
    void startFixture()throws Exception{
        server=new ServerSocket(0,16,InetAddress.getByName("127.0.0.1"));
        Thread worker=new Thread(()->{while(!server.isClosed())try(Socket socket=server.accept()){
            socket.setSoTimeout(5000);BufferedReader in=new BufferedReader(new InputStreamReader(socket.getInputStream(),StandardCharsets.UTF_8));
            String first=in.readLine();if(first==null)continue;String line;while((line=in.readLine())!=null&&!line.isEmpty()){}
            String[] request=first.split(" ");boolean get=request[0].equals("GET");byte[] body=(get?response(request[1]).toString():"{}").getBytes(StandardCharsets.UTF_8);
            OutputStream out=socket.getOutputStream();out.write(("HTTP/1.1 "+(get?"200 OK":"405 Method Not Allowed")+"\r\nContent-Type: application/json\r\nContent-Length: "+body.length+"\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));out.write(body);out.flush();
        }catch(Exception ignored){}});worker.setDaemon(true);worker.start();
    }
    void capture(MainActivity a,String name,int selected)throws Exception{
        ready(a);final JSONObject[] result=new JSONObject[1];
        runOnMainSync(()->{try{
            JSONArray items=new JSONArray();boolean aligned=true,visible=true;float density=a.getResources().getDisplayMetrics().density;
            for(int i=0;i<a.nav.getChildCount();i++){
                LinearLayout item=(LinearLayout)a.nav.getChildAt(i);ImageView image=(ImageView)item.getChildAt(0);TextView label=(TextView)item.getChildAt(1);
                int[] ip=new int[2],tp=new int[2],vp=new int[2];image.getLocationOnScreen(ip);label.getLocationOnScreen(tp);item.getLocationOnScreen(vp);
                float imageCenter=ip[0]+image.getWidth()/2f;
                float textCenter=tp[0]+label.getCompoundPaddingLeft()-label.getScrollX()+(label.getLayout().getLineLeft(0)+label.getLayout().getLineRight(0))/2;
                float offset=Math.abs(imageCenter-textCenter)/density;
                float textTop=tp[1]+label.getTotalPaddingTop()+label.getLayout().getLineTop(0);
                float textBottom=tp[1]+label.getTotalPaddingTop()+label.getLayout().getLineBottom(0);
                float gap=(textTop-ip[1]-image.getHeight())/density;
                boolean full=label.getLineCount()==1&&label.getLayout().getEllipsisCount(0)==0&&label.getLayout().getLineWidth(0)<=label.getWidth()-label.getCompoundPaddingLeft()-label.getCompoundPaddingRight()+1&&textBottom<=vp[1]+item.getHeight()+1&&item.getHeight()>=a.dp(48);
                aligned&=offset<=1;visible&=full&&gap>=2&&gap<=12;
                if(expectedAligned&&item.isSelected()!=(i==selected))throw new IOException("Wrong selected tab: "+name);
                items.put(json("label",label.getText(),"center_offset_dp",offset,"icon_text_gap_dp",gap,"text_visible",full,"touch_height_dp",item.getHeight()/density));
            }
            result[0]=json("screen",name,"page",a.page,"font_scale",a.getResources().getConfiguration().fontScale,"screen_width_dp",a.getResources().getConfiguration().screenWidthDp,"aligned",aligned,"visible",visible,"tabs",items);
        }catch(Exception e){throw new RuntimeException(e);}});
        pages.put(result[0]);
        try(FileOutputStream out=new FileOutputStream(new File(context.getFilesDir(),runName+"-"+name+".png"))){getUiAutomation().takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,out);}
        if(expectedAligned&&(!result[0].getBoolean("aligned")||!result[0].getBoolean("visible")))throw new IOException("Navigation geometry failed: "+name);
    }
    void tabs(MainActivity a,String prefix,String[] expected)throws Exception{
        for(int i=0;i<4;i++){final int tab=i;ui(()->a.nav.getChildAt(tab).performClick());ready(a);if(!a.page.equals(expected[i]))throw new IOException("Navigation destination mismatch");capture(a,prefix+"-"+new String[]{"library","ask","tasks","account"}[i],i);}
    }
    @Override public void onStart(){
        boolean ok=false;JSONObject report=new JSONObject();context=getTargetContext();
        try{
            if(!context.getPackageName().equals("com.teno.app.navigationverification"))throw new IOException("Use the isolated verification application");
            startFixture();Store store=new Store(context);store.base("http://127.0.0.1:"+server.getLocalPort());store.identity("Layout review","layout-fixture");store.markNativePreferences();store.tokens(json("access_token","local-fixture-only"));
            personal=(MainActivity)startActivitySync(new Intent(context,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready(personal);
            tabs(personal,"personal",new String[]{"home","chats","resource","settings"});
            ui(()->personal.resources("events"));capture(personal,"personal-calendar",2);
            if(expectedAligned){ui(()->personal.resources("folders"));capture(personal,"personal-folders",0);ui(()->personal.resources("memories"));capture(personal,"personal-context",3);}
            JSONObject workspace=json("id","visual","name","Product team","membership",json("id","demo-member","role","admin"));
            team=(TeamActivity)startActivitySync(new Intent(context,TeamActivity.class).putExtra("team",workspace.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ready(team);
            tabs(team,"team",new String[]{"team_meetings","team_chats","team_tasks","team_account"});
            ui(()->team.listMeetings("group_chat"));capture(team,"team-group-chats",0);
            ui(team::knowledge);capture(team,"team-knowledge",0);
            ui(team::knowledgeSearch);capture(team,"team-search",0);
            if(!expectedAligned){boolean found=false;for(int i=0;i<pages.length();i++)found|=!pages.getJSONObject(i).getBoolean("aligned");if(!found)throw new IOException("Baseline defect not reproduced");}
            ok=true;
        }catch(Throwable e){try{report.put("failure",e.toString());}catch(Exception ignored){}}
        finally{
            try{if(team!=null)ui(team::finish);if(personal!=null)ui(personal::finish);}catch(Exception ignored){}
            if(server!=null)try{server.close();}catch(Exception ignored){}
            try{report.put("all_passed",ok).put("expected_aligned",expectedAligned).put("screens",pages).put("scope","API 35 emulator; synthetic read-only loopback data. No physical-device or backend acceptance.");Files.write(new File(context.getFilesDir(),runName+"-navigation-report.json").toPath(),report.toString(2).getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}
            Bundle b=new Bundle();b.putString("stream",report.toString());finish(ok?Activity.RESULT_OK:Activity.RESULT_CANCELED,b);
        }
    }
}
