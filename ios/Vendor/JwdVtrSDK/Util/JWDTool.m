//
//  JWDTool.m
//  JwdVtrSDK
//

#import "JWDTool.h"

// static const char HEX_CHAR[] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

@implementation JWDTool

+ (NSString *)bytesToHexString:(const uint8_t *)bytes length:(NSUInteger)length {
    if (!bytes || length == 0) return @"";
    NSMutableString *result = [NSMutableString stringWithCapacity:length * 3];
    for (NSUInteger i = 0; i < length; i++) {
        if (i > 0) [result appendString:@" "];
        [result appendFormat:@"%02X", bytes[i]];
    }
    return [result uppercaseString];
}

+ (NSString *)dataToHexString:(NSData *)data {
    if (!data || data.length == 0) return @"";
    return [self bytesToHexString:(const uint8_t *)data.bytes length:data.length];
}

+ (NSString *)stringToAscii:(NSString *)val {
    if (!val || val.length == 0) return @"";
    NSMutableString *builder = [NSMutableString string];
    for (NSUInteger i = 0; i < val.length; i++) {
        unichar c = [val characterAtIndex:i];
        if (i < val.length - 1) {
            [builder appendFormat:@"%d,", (int)c];
        } else {
            [builder appendFormat:@"%d", (int)c];
        }
    }
    return builder;
}

+ (NSString *)asciiToHex:(NSString *)val {
    if (!val || val.length == 0) return @"";
    NSArray<NSString *> *asciiArr = [val componentsSeparatedByString:@","];
    NSMutableString *builder = [NSMutableString string];
    for (NSUInteger i = 0; i < asciiArr.count; i++) {
        int num = [asciiArr[i] intValue];
        NSString *hex = [self numToHex16:num];
        if (i < asciiArr.count - 1) {
            [builder appendFormat:@"%@ ", hex];
        } else {
            [builder appendString:hex];
        }
    }
    return builder;
}

+ (NSString *)hexStringToAsciiString:(NSString *)hex {
    if (!hex || hex.length == 0) return @"";
    NSArray<NSString *> *parts = [hex componentsSeparatedByString:@" "];
    NSMutableString *result = [NSMutableString string];
    for (NSString *part in parts) {
        if (part.length == 0) continue;
        unsigned int decimal = 0;
        NSScanner *scanner = [NSScanner scannerWithString:part];
        [scanner scanHexInt:&decimal];
        [result appendFormat:@"%c", (char)decimal];
    }
    return result;
}

+ (NSData *)hexStringToData:(NSString *)hexString {
    if (!hexString || hexString.length == 0) return [NSData data];
    NSString *cleaned = [hexString stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger i = 0; i < cleaned.length; i += 2) {
        if (i + 2 > cleaned.length) break;
        NSString *byteStr = [cleaned substringWithRange:NSMakeRange(i, 2)];
        unsigned int byteVal = 0;
        NSScanner *scanner = [NSScanner scannerWithString:byteStr];
        [scanner scanHexInt:&byteVal];
        uint8_t byte = (uint8_t)byteVal;
        [data appendBytes:&byte length:1];
    }
    return data;
}

+ (NSString *)numToHex16:(int)num {
    return [NSString stringWithFormat:@"%02X", num & 0xFF];
}

+ (NSString *)currentTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    return [formatter stringFromDate:[NSDate date]];
}

@end
