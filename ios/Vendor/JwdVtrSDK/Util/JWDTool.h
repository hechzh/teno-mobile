//
//  JWDTool.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 通用工具类（字符串/字节/16进制转换）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JWDTool : NSObject

/**
 * byte[] 转 16进制字符串（空格分隔）
 * 例: {0x41, 0x42} -> "41 42"
 */
+ (NSString *)bytesToHexString:(const uint8_t *)bytes length:(NSUInteger)length;
+ (NSString *)dataToHexString:(NSData *)data;

/**
 * 字符串转 ASCII 码（逗号分隔的十进制）
 * 例: "AB" -> "65,66"
 */
+ (NSString *)stringToAscii:(NSString *)val;

/**
 * ASCII 码（逗号分隔十进制）转 16进制字符串（空格分隔）
 * 例: "65,66" -> "41 42"
 */
+ (NSString *)asciiToHex:(NSString *)val;

/**
 * 16进制字符串（空格分隔）逐字节转 ASCII 字符拼接
 * 例: "41 42" -> "AB"
 */
+ (NSString *)hexStringToAsciiString:(NSString *)hex;

/**
 * 16进制字符串（空格分隔）转 NSData
 */
+ (NSData *)hexStringToData:(NSString *)hexString;

/**
 * 十进制整数转两位16进制字符串
 */
+ (NSString *)numToHex16:(int)num;

/**
 * 获取当前时间字符串（yyyyMMddHHmmss 格式）
 */
+ (NSString *)currentTimeString;

@end

NS_ASSUME_NONNULL_END
