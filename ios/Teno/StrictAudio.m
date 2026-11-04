#import "StrictAudio.h"
#include <opus.h>
#include <zlib.h>

static BOOL fail(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"TenoAudio" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
@implementation StrictAudio
+ (BOOL)decodeOpus:(NSURL *)input output:(NSURL *)output error:(NSError **)error {
    FILE *src = fopen(input.fileSystemRepresentation, "rb");
    if (!src) return fail(error, @"The downloaded audio is unavailable.");
    FILE *dst = fopen(output.fileSystemRepresentation, "wb");
    if (!dst) { fclose(src); return fail(error, @"Could not save decoded audio."); }
    int code = 0; OpusDecoder *decoder = opus_decoder_create(16000, 1, &code);
    unsigned char frame[80], header[44] = {0}; opus_int16 pcm[5760];
    size_t got; uint32_t count = 0; BOOL valid = decoder && code == OPUS_OK;
    if (fwrite(header, 1, 44, dst) != 44) valid = NO;
    while (valid && (got = fread(frame, 1, 80, src)) > 0) {
        if (got != 80) { valid = NO; break; }
        int samples = opus_decode(decoder, frame, 80, pcm, 5760, 0);
        // Never insert PLC or skip a damaged frame in a final recording.
        if (samples != 320 || count + 640 > 60 * 60 * 32000 || fwrite(pcm, 2, samples, dst) != (size_t)samples) { valid = NO; break; }
        count += 640;
    }
    if (ferror(src) || count == 0) valid = NO;
    if (valid) {
        memcpy(header, "RIFF", 4); uint32_t n = CFSwapInt32HostToLittle(count + 36); memcpy(header+4, &n, 4);
        memcpy(header+8, "WAVEfmt ", 8); n = CFSwapInt32HostToLittle(16); memcpy(header+16, &n, 4);
        header[20]=1; header[22]=1; n=CFSwapInt32HostToLittle(16000); memcpy(header+24,&n,4);
        n=CFSwapInt32HostToLittle(32000); memcpy(header+28,&n,4); header[32]=2; header[34]=16;
        memcpy(header+36,"data",4); n=CFSwapInt32HostToLittle(count); memcpy(header+40,&n,4);
        if (fseek(dst,0,SEEK_SET) || fwrite(header,1,44,dst)!=44 || fflush(dst)) valid=NO;
    }
    if (decoder) opus_decoder_destroy(decoder);
    fclose(src); if (fclose(dst)) valid=NO;
    if (!valid) { [[NSFileManager defaultManager] removeItemAtURL:output error:nil]; return fail(error, @"A damaged or unsupported Opus frame was found. No upload was queued."); }
    return YES;
}
+ (NSString *)crc32:(NSURL *)input error:(NSError **)error {
    FILE *src = fopen(input.fileSystemRepresentation,"rb");
    if (!src) { fail(error,@"The downloaded file is unavailable."); return @""; }
    unsigned char buffer[65536]; size_t count; uLong crc=crc32(0L,Z_NULL,0);
    while ((count=fread(buffer,1,sizeof(buffer),src))>0) crc=crc32(crc,buffer,(uInt)count);
    BOOL ok=!ferror(src); fclose(src);
    if (!ok) { fail(error,@"The downloaded file could not be read."); return @""; }
    return [NSString stringWithFormat:@"%08lX",(unsigned long)crc];
}
@end
