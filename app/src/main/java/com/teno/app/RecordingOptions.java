package com.teno.app;

import android.app.*;
import android.widget.*;

/** A remembered choice for cloud processing. Local retention is unconditional. */
final class RecordingOptions {
    static void ensure(Activity activity,Runnable next){
        Store store=new Store(activity);
        if(store.scope().isEmpty()||store.recordingOptionsSet())next.run();else show(activity,next);
    }
    static AlertDialog show(Activity activity,Runnable next){
        Store store=new Store(activity);int pad=(int)(24*activity.getResources().getDisplayMetrics().density);
        LinearLayout form=new LinearLayout(activity);form.setOrientation(LinearLayout.VERTICAL);form.setPadding(pad,pad/2,pad,pad/2);
        TextView notice=new TextView(activity);notice.setText("Audio is always saved on this phone. Original files stay on your recorder.\n\nNew recorder files sync automatically when connected. Cloud processing uploads a copy to your personal library for transcription and a summary. Team sharing is a separate action.");form.addView(notice);
        CheckBox cloud=new CheckBox(activity);cloud.setText("Automatic cloud processing");cloud.setChecked(!store.recordingOptionsSet()||store.autoUpload());form.addView(cloud);
        CheckBox wifi=new CheckBox(activity);wifi.setText("Upload on Wi-Fi only");wifi.setChecked(store.wifiUpload());form.addView(wifi);
        TextView label=new TextView(activity);label.setText("Transcription language");label.setPadding(0,pad/2,0,pad/3);form.addView(label);
        Spinner language=new Spinner(activity);language.setAdapter(new ArrayAdapter<>(activity,android.R.layout.simple_spinner_dropdown_item,new String[]{"Chinese (Mandarin)","English (US)"}));language.setSelection(store.language().equals("en-US")?1:0);form.addView(language);
        CheckBox live=new CheckBox(activity);live.setText("Live transcription");live.setChecked(store.liveDefault());form.addView(live);
        TextView liveNote=new TextView(activity);liveNote.setText("Live transcription sends audio while you record and can use mobile data. These settings apply to the next recording.");form.addView(liveNote);
        ScrollView scroll=new ScrollView(activity);scroll.addView(form);
        return new AlertDialog.Builder(activity).setTitle("Recording preferences").setView(scroll).setPositiveButton(next==null?"Save":"Save and continue",(d,w)->{
            store.language(language.getSelectedItemPosition()==1?"en-US":"zh-CN");store.recordingOptions(cloud.isChecked(),wifi.isChecked(),live.isChecked());
            UploadQueue.resume(activity);if(next!=null)next.run();
        }).setNegativeButton("Cancel",null).show();
    }
}
