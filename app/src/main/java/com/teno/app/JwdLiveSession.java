package com.teno.app;

import com.actions.asc.jni.ASCDecoder;
import java.io.*;
import java.nio.*;
import java.util.*;
import java.util.concurrent.*;

/** Preview only. A complete device file must still pass the ordinary import checks. */
final class JwdLiveSession {
    private final ArrayBlockingQueue<byte[]> queue=new ArrayBlockingQueue<>(256);
    private final Thread worker;
    private volatile boolean accepting=true;
    private volatile int queuedBytes;
    volatile boolean finished;
    volatile String problem="";
    volatile long samples;
    final LiveTranscriber transcriber;
    JwdLiveSession(Store store,String name){
        transcriber=new LiveTranscriber(store,"jwd-preview-"+UUID.randomUUID(),name,store.language());
        worker=new Thread(this::decode,"TenoJwdLive");worker.start();
    }
    synchronized void feed(byte[] data){
        if(!accepting||data.length==0)return;
        if(data.length>65536||queuedBytes+data.length>320000||!queue.offer(data.clone())){
            problem="Audio stream interrupted. Import the complete recording after stopping.";accepting=false;transcriber.gap=true;return;
        }
        queuedBytes+=data.length;
    }
    void stop(boolean confirmed){
        if(!confirmed){problem="Connection ended. Check the recorder before importing the complete file.";transcriber.gap=true;}
        accepting=false;
    }
    private void decode(){
        boolean initialized=false;byte[] remainder=new byte[0];
        try{
            // The vendor decoder is a process-wide singleton. Never overlap file and live decoding.
            synchronized(JwdAudio.class){
                try{
                    ASCDecoder decoder=ASCDecoder.getInstance();decoder.init((short)ASCDecoder.ASC_VI);initialized=true;
                    while(accepting||!queue.isEmpty()){
                        byte[] data=queue.poll(100,TimeUnit.MILLISECONDS);if(data==null)continue;
                        synchronized(this){queuedBytes-=data.length;}
                        byte[] combined=new byte[remainder.length+data.length];System.arraycopy(remainder,0,combined,0,remainder.length);System.arraycopy(data,0,combined,remainder.length,data.length);
                        int offset=0;
                        while(offset+80<=combined.length){
                            byte[] frame=Arrays.copyOfRange(combined,offset,offset+80);offset+=80;
                            if(!JwdAudio.opusFrame(frame))throw new IOException("Live audio format is unsupported or damaged. Import the complete recording after stopping.");
                            short[] encoded=new short[40];ByteBuffer.wrap(frame).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(encoded);
                            short[] pcm=decoder.decode(encoded,(short)40,(short)ASCDecoder.ASC_VI);
                            if(pcm==null||pcm.length!=320)throw new IOException("Live audio could not be decoded. Import the complete recording after stopping.");
                            byte[] bytes=new byte[640];ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().put(pcm);samples+=320;transcriber.feed(bytes,bytes.length);
                        }
                        remainder=Arrays.copyOfRange(combined,offset,combined.length);
                    }
                    if(remainder.length>0){problem="The live stream ended with an incomplete packet. Import the complete recording.";transcriber.gap=true;}
                }finally{if(initialized)ASCDecoder.destroy();}
            }
        }catch(Exception|LinkageError e){problem=e.getMessage()==null?"Live audio is unavailable on this phone.":e.getMessage();transcriber.gap=true;}
        finally{accepting=false;queue.clear();transcriber.finish();finished=true;}
    }
}
