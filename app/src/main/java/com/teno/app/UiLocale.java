package com.teno.app;

import android.content.Context;
import android.content.res.Configuration;
import java.util.Locale;

/** UI-only locale. Never touches account, ASR, recording or upload preferences. */
final class UiLocale {
    static String preference(Context context){
        return context.getSharedPreferences("teno.ui",0).getString("locale","system");
    }
    static void set(Context context,String value){
        if(!value.equals("system")&&!value.equals("zh")&&!value.equals("en"))throw new IllegalArgumentException("Invalid interface language.");
        if(!context.getSharedPreferences("teno.ui",0).edit().putString("locale",value).commit())throw new IllegalStateException("Could not save interface language.");
    }
    static Locale locale(Context context){
        String chosen=preference(context);
        if(chosen.equals("system")){
            Locale original=android.content.res.Resources.getSystem().getConfiguration().getLocales().get(0);
            return original.getLanguage().equals("zh")?Locale.SIMPLIFIED_CHINESE:Locale.US;
        }
        return chosen.equals("zh")?Locale.SIMPLIFIED_CHINESE:Locale.US;
    }
    static Context localized(Context context){
        Configuration c=new Configuration(context.getResources().getConfiguration());
        c.setLocale(locale(context));return context.createConfigurationContext(c);
    }
    static String text(Context context,String source){
        int resource=UiLocaleLabels.resource(source);
        if(resource!=0)return text(context,resource);
        if(locale(context).getLanguage().equals("zh") && source.matches("Uploading [0-9]+%"))return "正在上传 "+source.substring(10);
        return source;
    }
    static String text(Context context,int id){return localized(context).getString(id);}
}
