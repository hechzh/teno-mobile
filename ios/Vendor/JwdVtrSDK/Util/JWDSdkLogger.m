//
//  JWDSdkLogger.m
//  JwdVtrSDK
//

#import "JWDSdkLogger.h"

static BOOL _isDebugEnabled = NO;

// 2026-10-10 日志时间戳：Xcode 控制台默认剥离 NSLog 的系统时间戳，
// 复制出来的日志无法分析时序（如"距断开多久"）。在 SDK 日志行内
// 自带 HH:mm:ss.SSS 毫秒时间戳，使每行日志自包含。
// NSDateFormatter 创建开销大且日志高频（Socket 每包一条），
// 静态缓存 + 锁定本地时区，线程安全（iOS 7+ stringFromDate 线程安全）。
static NSDateFormatter *JWDLogTimeFormatter(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss.SSS";
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone systemTimeZone];
    });
    return formatter;
}

static NSString *JWDLogTimestamp(void) {
    return [JWDLogTimeFormatter() stringFromDate:[NSDate date]];
}

@implementation JWDSdkLogger

+ (void)setDebugEnabled:(BOOL)enabled {
    _isDebugEnabled = enabled;
    NSLog(@"[SdkLogger] Debug mode: %@", enabled ? @"ENABLED" : @"DISABLED");
}

+ (BOOL)isDebugEnabled {
    return _isDebugEnabled;
}

+ (void)v:(NSString *)tag msg:(NSString *)msg {
    if (_isDebugEnabled) {
        NSLog(@"[%@][V][%@] %@", JWDLogTimestamp(), tag, msg);
    }
}

+ (void)d:(NSString *)tag msg:(NSString *)msg {
    if (_isDebugEnabled) {
        NSLog(@"[%@][D][%@] %@", JWDLogTimestamp(), tag, msg);
    }
}

+ (void)i:(NSString *)tag msg:(NSString *)msg {
    NSLog(@"[%@][I][%@] %@", JWDLogTimestamp(), tag, msg);
}

+ (void)w:(NSString *)tag msg:(NSString *)msg {
    NSLog(@"[%@][W][%@] %@", JWDLogTimestamp(), tag, msg);
}

+ (void)e:(NSString *)tag msg:(NSString *)msg {
    NSLog(@"[%@][E][%@] %@", JWDLogTimestamp(), tag, msg);
}

+ (void)logProtocolSend:(NSString *)tag protocol:(NSString *)protocol {
    if (_isDebugEnabled) {
        NSLog(@"[%@][D][%@] [SEND] %@", JWDLogTimestamp(), tag, protocol);
    }
}

+ (void)logProtocolReceive:(NSString *)tag protocol:(NSString *)protocol {
    if (_isDebugEnabled) {
        NSLog(@"[%@][D][%@] [RECV] %@", JWDLogTimestamp(), tag, protocol);
    }
}

@end
