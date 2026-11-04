#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface StrictAudio : NSObject
+ (BOOL)decodeOpus:(NSURL *)input output:(NSURL *)output error:(NSError **)error;
+ (NSString *)crc32:(NSURL *)input error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
