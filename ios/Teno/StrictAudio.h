#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface StrictAudio : NSObject
+ (BOOL)decodeOpus:(NSURL *)input output:(NSURL *)output error:(NSError **)error;
+ (nullable NSString *)crc32:(NSURL *)input error:(NSError **)error;
+ (uint32_t)updateCRC32:(uint32_t)checksum bytes:(NSData *)bytes NS_SWIFT_NAME(updateCRC32(_:bytes:));
@end
NS_ASSUME_NONNULL_END
