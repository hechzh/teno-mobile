package com.teno.app;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

public final class JwdProtocolTest {
    interface Work {void run()throws Exception;}
    static int count=0;
    static void check(boolean ok,String name){if(!ok)throw new AssertionError(name);count++;System.out.println("PASS "+name);}
    static void rejects(Work task,String name)throws Exception{try{task.run();throw new AssertionError(name);}catch(IOException expected){count++;System.out.println("PASS "+name);}}
    public static void main(String[] args)throws Exception{
        byte[] bytes="123456789".getBytes(StandardCharsets.US_ASCII);Path dir=Files.createTempDirectory("teno-jwd-test-");
        try{
            check(Arrays.equals(JwdProtocol.encode("APP&STA"),"APP&STA".getBytes(StandardCharsets.US_ASCII)),"sdk_ascii_command_compatibility");
            check(JwdProtocol.candidateName("VTR7900_P_123"),"vendor_vtr_name_candidate");
            check(JwdProtocol.candidateName("HQ-10_HW_123"),"vendor_mp3_name_candidate");
            check(JwdProtocol.candidateName("Dex_123"),"vendor_odm_name_candidate");
            check(!JwdProtocol.candidateName("SGMf91a73"),"reported_sgm_name_not_in_vendor_name_list");
            check(!JwdProtocol.candidateName(null),"unnamed_device_not_name_matched");
            Set<String> keys=new HashSet<>();for(int i=0;i<1000;i++){String key=JwdProtocol.newKey();if(!JwdProtocol.validKey(key))throw new AssertionError("invalid key");keys.add(key);}check(keys.size()==1000,"unique_device_keys");
            rejects(()->JwdProtocol.part("../../file"),"path_traversal_rejected");rejects(()->JwdProtocol.part("file&STA"),"command_injection_rejected");
            check(JwdProtocol.replies("MCU&RT&0\0".getBytes(StandardCharsets.US_ASCII))[0].equals("MCU&RT&0"),"idle_record_reply");
            check(JwdProtocol.replies("MCU&SK&OKMCU&BAT&90".getBytes(StandardCharsets.US_ASCII)).length==2,"coalesced_replies");
            File valid=dir.resolve("valid.raw").toFile();
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(valid,9)){r.write(Arrays.copyOfRange(bytes,0,4));r.write(Arrays.copyOfRange(bytes,4,9));check(!r.complete(),"length_alone_not_complete");r.end("cbf43926");check(r.finish().equals("crc32_verified"),"known_crc32_vector");}
            check(JwdProtocol.crcFile(valid).equals("CBF43926"),"disk_crc_matches");
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(dir.resolve("late.raw").toFile(),9)){r.write(Arrays.copyOfRange(bytes,0,4));r.end("CBF43926");check(!r.complete(),"end_marker_alone_not_complete");r.write(Arrays.copyOfRange(bytes,4,9));check(r.finish().equals("crc32_verified"),"cross_characteristic_late_audio");}
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(dir.resolve("crc.raw").toFile(),9)){r.write(bytes);r.end("00000000");rejects(r::finish,"corrupt_crc_blocked");}
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(dir.resolve("short.raw").toFile(),10)){r.write(bytes);r.end("CBF43926");rejects(r::finish,"truncated_file_blocked");}
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(dir.resolve("extra.raw").toFile(),8)){rejects(()->r.write(bytes),"overflow_blocked");}
            try(JwdProtocol.Receiver r=new JwdProtocol.Receiver(dir.resolve("legacy.raw").toFile(),9)){r.write(bytes);r.end(null);check(r.finish().equals("length_only"),"legacy_crc_not_falsely_verified");}
            rejects(()->new JwdProtocol.Receiver(dir.resolve("large.raw").toFile(),JwdProtocol.MAX_BYTES+1),"size_bound");
            rejects(()->JwdProtocol.crc("bad"),"malformed_crc_blocked");
            System.out.println("ALL "+count+" CHECKS PASSED");
        }finally{try(java.util.stream.Stream<Path> files=Files.list(dir)){for(Path file:(Iterable<Path>)files::iterator)Files.deleteIfExists(file);}Files.delete(dir);}
    }
}
