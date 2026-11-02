package com.teno.app;

import android.content.Context;
import android.view.*;

/** Keeps filter labels intact and wraps whole controls, with consistent gaps. */
final class FlowLayout extends ViewGroup {
    private final int gap;
    FlowLayout(Context context,int gap){super(context);this.gap=gap;}
    @Override protected void onMeasure(int widthSpec,int heightSpec){
        int width=MeasureSpec.getSize(widthSpec),x=0,y=0,rowHeight=0;
        for(int i=0;i<getChildCount();i++){View child=getChildAt(i);if(child.getVisibility()==GONE)continue;
            child.measure(MeasureSpec.makeMeasureSpec(width,MeasureSpec.AT_MOST),MeasureSpec.makeMeasureSpec(0,MeasureSpec.UNSPECIFIED));
            if(x>0&&x+child.getMeasuredWidth()>width){x=0;y+=rowHeight+gap;rowHeight=0;}
            x+=child.getMeasuredWidth()+gap;rowHeight=Math.max(rowHeight,child.getMeasuredHeight());
        }
        setMeasuredDimension(width,resolveSize(y+rowHeight,heightSpec));
    }
    @Override protected void onLayout(boolean changed,int left,int top,int right,int bottom){
        int width=right-left,x=0,y=0,rowHeight=0;
        for(int i=0;i<getChildCount();i++){View child=getChildAt(i);if(child.getVisibility()==GONE)continue;
            int w=child.getMeasuredWidth(),h=child.getMeasuredHeight();if(x>0&&x+w>width){x=0;y+=rowHeight+gap;rowHeight=0;}
            child.layout(x,y,x+w,y+h);x+=w+gap;rowHeight=Math.max(rowHeight,h);
        }
    }
}
