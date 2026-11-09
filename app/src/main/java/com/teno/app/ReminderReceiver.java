package com.teno.app;
import android.app.*;
import android.content.*;
public final class ReminderReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c,Intent i){
        if(!new Store(c).scope().equals(i.getStringExtra("scope")))return;
        RecorderService.channel(c,"reminders","Task and event reminders");
        Notification n=new Notification.Builder(c,"reminders").setSmallIcon(R.drawable.ic_app).setContentTitle(UiLocale.text(c,"Teno · Reminder")).setContentText(i.getStringExtra("title")).setContentIntent(RecorderService.home(c)).setAutoCancel(true).build();
        ((NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE)).notify(i.getIntExtra("id",1),n);
    }
}
