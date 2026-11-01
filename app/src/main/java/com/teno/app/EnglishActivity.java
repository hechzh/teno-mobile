package com.teno.app;
import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import java.util.Locale;
/** Interface locale does not change the selected speech-recognition language. */
public class EnglishActivity extends Activity {
    @Override protected void attachBaseContext(Context base){Locale.setDefault(Locale.US);Configuration c=new Configuration(base.getResources().getConfiguration());c.setLocale(Locale.US);super.attachBaseContext(base.createConfigurationContext(c));}
}
