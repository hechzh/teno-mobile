package com.teno.app;
import android.content.Context;
import android.graphics.*;
import android.view.View;
import org.json.*;
import java.util.*;

/** A static, readable tree with every relationship drawn; no hidden hover edges. */
public final class MindMapView extends View {
    private static class Node {String title;int depth,parent;Node(String t,int d,int p){title=t;depth=d;parent=p;}}
    private final List<Node> nodes=new ArrayList<>();private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    public MindMapView(Context c,JSONObject data){super(c);walk(data,0,-1);setLayerType(View.LAYER_TYPE_SOFTWARE,null);}
    private void walk(JSONObject o,int depth,int parent){if(o==null||nodes.size()>=100)return;int index=nodes.size();nodes.add(new Node(o.optString("title"),depth,parent));JSONArray children=o.optJSONArray("children");if(children!=null)for(int i=0;i<children.length();i++)walk(children.optJSONObject(i),depth+1,index);}
    public int nodeCount(){return nodes.size();}
    private float dp(float v){return v*getResources().getDisplayMetrics().density;}
    @Override protected void onDraw(Canvas c){super.onDraw(c);c.drawColor(Color.WHITE);float step=dp(58);for(int i=0;i<nodes.size();i++){Node n=nodes.get(i);float x=dp(12+n.depth*20),y=dp(12)+i*step;paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(dp(1.5f));paint.setColor(0xffc7c0eb);if(n.parent>=0){Node p=nodes.get(n.parent);float px=dp(12+p.depth*20)+dp(7),py=dp(12)+n.parent*step+dp(34);c.drawLine(px,py,px,y+dp(17),paint);c.drawLine(px,y+dp(17),x,y+dp(17),paint);}paint.setStyle(Paint.Style.FILL);paint.setColor(n.depth==0?0xff6253c5:0xfff0eef9);c.drawRoundRect(x,y,getWidth()-dp(4),y+dp(42),dp(10),dp(10),paint);paint.setColor(n.depth==0?Color.WHITE:0xff383244);paint.setTextSize(dp(13));String title=n.title;float width=getWidth()-x-dp(24);while(title.length()>1&&paint.measureText(title)>width)title=title.substring(0,title.length()-1);if(!title.equals(n.title)&&title.length()>1)title=title.substring(0,title.length()-1)+"…";c.drawText(title,x+dp(9),y+dp(26),paint);}}
}
