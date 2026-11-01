package com.teno.app;

import android.content.Context;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;

/** Account-scoped originals and upload receipts, separate from personal drafts. */
final class TeamAudioStore {
    final File folder;
    TeamAudioStore(Context c,Store store){folder=new File(c.getFilesDir(),"team-audio/"+store.scope());folder.mkdirs();}
    JSONObject load(String id)throws Exception{
        if(!id.matches("[a-f0-9-]{36}"))throw new IOException("Invalid upload identifier");
        return new JSONObject(new String(Files.readAllBytes(new File(folder,id+".json").toPath()),StandardCharsets.UTF_8));
    }
    void save(JSONObject data)throws Exception{Store.save(folder,data);}
    JSONArray list(String team){JSONArray result=new JSONArray();File[] files=folder.listFiles((d,n)->n.endsWith(".json"));if(files==null)return result;
        Arrays.sort(files,Comparator.comparingLong(File::lastModified).reversed());for(File file:files)try{JSONObject d=load(file.getName().replace(".json",""));if(team.equals(d.optString("team_id")))result.put(d);}catch(Exception ignored){}return result;}
}
