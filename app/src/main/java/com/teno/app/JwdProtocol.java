package com.teno.app;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.*;
import java.util.zip.CRC32;

/** JWD protocol V1.1 (2026-10-22), matching SDK ProtocolClient / ReplyParser. */
public final class JwdProtocol {
    public static final UUID SERVICE=UUID.fromString("001120a0-2233-4455-6677-889912345678");
    public static final UUID AUDIO=UUID.fromString("001120a1-2233-4455-6677-889912345678");
    public static final UUID WRITE=UUID.fromString("001120a2-2233-4455-6677-889912345678");
    public static final UUID COMMAND=UUID.fromString("001120a3-2233-4455-6677-889912345678");
    public static final UUID CCCD=UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    public static final long MAX_BYTES=100L*1024*1024;
    /** Name is a hint from the supplied SDK, never proof of the GATT service. */
    public static boolean candidateName(String name){
        if(name==null)return false;String n=name.toUpperCase(Locale.ROOT);
        for(String prefix:new String[]{"VTR","H10","H11","HQ10","HQ11","HQ-10_P","HQ-11_P","HQ-10_HW","DEX_"})if(n.startsWith(prefix))return true;
        return false;
    }
    public static String newKey(){
        String alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        SecureRandom random=new SecureRandom();StringBuilder s=new StringBuilder();
        for(int i=0;i<16;i++)s.append(alphabet.charAt(random.nextInt(alphabet.length())));
        return s.toString();
    }
    public static boolean validKey(String s){return s!=null&&s.matches("[A-Za-z0-9]{16}");}
    public static String part(String s)throws IOException{
        if(s==null||!s.matches("[A-Za-z0-9_.-]{1,100}")||s.equals(".")||s.equals(".."))throw new IOException("Invalid device filename");
        return s;
    }
    public static byte[] encode(String command)throws IOException{
        if(!command.startsWith("APP&")||!command.matches("[A-Za-z0-9&_.-]+")||command.length()>240)throw new IOException("Invalid device command");
        return command.getBytes(StandardCharsets.US_ASCII);
    }
    public static String[] replies(byte[] bytes)throws IOException{
        if(bytes.length==0||bytes.length>4096)throw new IOException("Invalid device response length");
        String s=new String(bytes,StandardCharsets.US_ASCII).replace("\u0000","").trim();
        if(!s.startsWith("MCU&")||!s.matches("[\\x20-\\x7e\\r\\n]+"))throw new IOException("Invalid device response format");
        return s.split("[\\r\\n]+|(?=MCU&)");
    }
    public static String crc(String s)throws IOException{
        if(s==null||s.isEmpty())return "";
        if(!s.matches("[a-fA-F0-9]{8}"))throw new IOException("Invalid device checksum format");
        return s.toUpperCase(Locale.ROOT);
    }
    public static String crcFile(File file)throws IOException{
        CRC32 crc=new CRC32();try(InputStream in=new FileInputStream(file)){byte[] b=new byte[65536];int n;while((n=in.read(b))!=-1)crc.update(b,0,n);}
        return String.format(Locale.ROOT,"%08X",crc.getValue());
    }
    /** Ordered, bounded disk receiver. Neither byte count nor OFF alone means success. */
    public static final class Receiver implements Closeable {
        public final File file;public final long expected;
        private final FileOutputStream out;private final CRC32 checksum=new CRC32();
        private long received;private boolean ended,closed;private String deviceCrc="";
        public Receiver(File file,long expected)throws IOException{
            if(expected<=0||expected>MAX_BYTES)throw new IOException("File size is invalid or exceeds 100 MiB");
            this.file=file;this.expected=expected;out=new FileOutputStream(file,false);
        }
        public long received(){return received;}
        public void write(byte[] b)throws IOException{
            if(closed||received+b.length>expected)throw new IOException("Received data exceeds the declared file length");
            out.write(b);checksum.update(b,0,b.length);received+=b.length;
        }
        public void end(String value)throws IOException{String next=crc(value);if(ended&&!deviceCrc.equals(next))throw new IOException("The final checksum does not match");deviceCrc=next;ended=true;}
        public boolean complete(){return ended&&received==expected;}
        public String finish()throws IOException{
            if(!complete())throw new IOException("The complete file has not been received");
            out.getFD().sync();close();
            String actual=String.format(Locale.ROOT,"%08X",checksum.getValue());
            if(!deviceCrc.isEmpty()&&!actual.equals(deviceCrc))throw new IOException("Checksum failed. Transfer the file again.");
            if(file.length()!=expected)throw new IOException("Local file length does not match");
            return deviceCrc.isEmpty()?"length_only":"crc32_verified";
        }
        public void close()throws IOException{if(!closed){closed=true;out.close();}}
    }
}
