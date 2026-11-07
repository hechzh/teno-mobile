package com.teno.app;

import android.media.MediaMetadataRetriever;
import com.actions.asc.jni.ASCDecoder;
import org.json.JSONObject;
import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

final class JwdAudio {
    interface Progress {void update(int percent);}
    static boolean opusFrame(byte[] b){
        if(b.length!=80)return false;int toc=b[0]&255;
        // SDK 1.1.3: SILK WB 20 ms, one frame per fixed 80-byte slot.
        if(toc==0x48)return true;
        if(toc!=0x4b||(b[1]&63)!=1||(b[1]&128)!=0)return false;
        if((b[1]&64)==0)return true;
        int pad=b[2]&255;if(pad>76)return false;
        for(int i=80-pad;i<80;i++)if(b[i]!=0)return false;
        return true;
    }
    static String format(File source)throws IOException{
        byte[] b=new byte[80];int n;try(InputStream in=new FileInputStream(source)){n=in.read(b);}
        if(n>=12&&new String(b,0,4,StandardCharsets.US_ASCII).equals("RIFF")&&new String(b,8,4,StandardCharsets.US_ASCII).equals("WAVE"))return ".wav";
        if(n>=3&&((b[0]=='I'&&b[1]=='D'&&b[2]=='3')||((b[0]&255)==255&&(b[1]&0xe0)==0xe0)))return ".mp3";
        if(n>=4&&new String(b,0,4,StandardCharsets.US_ASCII).equals("OggS"))return ".ogg";
        if(n==80&&opusFrame(b)&&source.length()%80==0)return "opus80";
        throw new IOException("Unsupported audio format. The original file was kept; export diagnostics for review.");
    }
    static synchronized void decode(File source,File output,Progress progress)throws IOException{
        if(source.length()==0||source.length()%80!=0)throw new IOException("The final audio packet is incomplete");
        long frames=source.length()/80,pcmBytes=frames*640;
        if(pcmBytes+44>JwdProtocol.MAX_BYTES)throw new IOException("Decoded audio exceeds the 100 MiB upload limit");
        boolean complete=false,initialized=false;
        try(RandomAccessFile out=new RandomAccessFile(output,"rw");DataInputStream in=new DataInputStream(new BufferedInputStream(new FileInputStream(source)))){
            ASCDecoder decoder=ASCDecoder.getInstance();decoder.init((short)ASCDecoder.ASC_VI);initialized=true;
            out.setLength(0);out.write(wavHeader(pcmBytes));byte[] frame=new byte[80];int last=-1;
            for(long i=0;i<frames;i++){
                if(Thread.currentThread().isInterrupted())throw new IOException("Audio decoding interrupted");
                in.readFully(frame);if(!opusFrame(frame))throw new IOException("Invalid Opus packet "+(i+1)+". The damaged audio was not skipped.");
                short[] encoded=new short[40];ByteBuffer.wrap(frame).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(encoded);
                short[] pcm=decoder.decode(encoded,(short)40,(short)ASCDecoder.ASC_VI);
                if(pcm==null||pcm.length!=320)throw new IOException("Audio decoding failed at packet "+(i+1)+")");
                ByteBuffer buffer=ByteBuffer.allocate(640).order(ByteOrder.LITTLE_ENDIAN);buffer.asShortBuffer().put(pcm);out.write(buffer.array());
                int percent=(int)((i+1)*100/frames);if(percent!=last){last=percent;progress.update(percent);}
            }
            out.getFD().sync();complete=true;
        }catch(LinkageError e){throw new IOException("The recorder decoder could not load on this phone. Keep the original file and report the phone model.",e);}
        finally{if(initialized)try{ASCDecoder.destroy();}catch(LinkageError ignored){}if(!complete)output.delete();}
    }
    static byte[] wavHeader(long bytes){
        ByteBuffer h=ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN);
        h.put("RIFF".getBytes(StandardCharsets.US_ASCII)).putInt((int)(bytes+36)).put("WAVEfmt ".getBytes(StandardCharsets.US_ASCII));
        h.putInt(16).putShort((short)1).putShort((short)1).putInt(16000).putInt(32000).putShort((short)2).putShort((short)16);
        h.put("data".getBytes(StandardCharsets.US_ASCII)).putInt((int)bytes);return h.array();
    }
    static JSONObject importVerified(Store store,File raw,String address,String dir,String name,long seconds,String verification,Progress progress)throws Exception{
        String crc=JwdProtocol.crcFile(raw),format=format(raw);
        String id=UUID.nameUUIDFromBytes((address+"\n"+dir+"\n"+name+"\n"+crc).getBytes(StandardCharsets.UTF_8)).toString();
        File metadata=new File(store.folder(),id+".json");
        if(metadata.isFile()){JSONObject old=store.draft(id);if(new File(old.getString("path")).isFile())return old;}
        JSONObject draft=store.newDraft("JWD "+name,format.equals("opus80")?".wav":format);
        File target=new File(store.folder(),id+(format.equals("opus80")?".wav":format));
        draft.put("id",id).put("path",target.getAbsolutePath());
        try{
            if(format.equals("opus80"))decode(raw,target,progress);else Files.copy(raw.toPath(),target.toPath(),StandardCopyOption.REPLACE_EXISTING);
            if(target.length()>JwdProtocol.MAX_BYTES)throw new IOException("Audio exceeds the 100 MiB upload limit");
            MediaMetadataRetriever reader=new MediaMetadataRetriever();long duration;
            try{reader.setDataSource(target.getAbsolutePath());duration=Long.parseLong(reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));}finally{reader.release();}
            if(duration<=0||duration>3600000)throw new IOException("Audio duration is invalid or exceeds 60 minutes");
            if(seconds>0&&Math.abs(duration-seconds*1000)>Math.max(3000,seconds*50))throw new IOException("Audio duration does not match the device file. The original file was kept.");
            draft.put("source","jwd_ble").put("jwd_device",address).put("jwd_directory",dir).put("jwd_file",name).put("jwd_crc32",crc).put("jwd_verification",verification).put("duration_ms",duration).put("source_bytes",raw.length());
            store.save(draft);return draft;
        }catch(Exception e){target.delete();throw e;}
    }
}
