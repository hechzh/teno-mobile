//
//  JWDSdkLogger.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 日志管理工具类
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * SDK 统一日志管理工具
 * 功能:
 * 1. 支持 Debug 模式开关，生产环境不输出敏感协议数据
 * 2. 协议收发仅在 Debug 模式下输出
 * 3. 错误和警告始终输出
 */
@interface JWDSdkLogger : NSObject

/**
 * 设置 Debug 模式
 * 注意：生产环境请设置为 NO
 * @param enabled YES=开启Debug, NO=关闭Debug
 */
+ (void)setDebugEnabled:(BOOL)enabled;

/** 获取当前 Debug 模式状态 */
+ (BOOL)isDebugEnabled;

/** VERBOSE 级别日志（仅 Debug 模式） */
+ (void)v:(NSString *)tag msg:(NSString *)msg;

/** DEBUG 级别日志（仅 Debug 模式） */
+ (void)d:(NSString *)tag msg:(NSString *)msg;

/** INFO 级别日志（始终输出） */
+ (void)i:(NSString *)tag msg:(NSString *)msg;

/** WARN 级别日志（始终输出） */
+ (void)w:(NSString *)tag msg:(NSString *)msg;

/** ERROR 级别日志（始终输出） */
+ (void)e:(NSString *)tag msg:(NSString *)msg;

/** 协议发送日志（仅 Debug 模式） */
+ (void)logProtocolSend:(NSString *)tag protocol:(NSString *)protocol;

/** 协议接收日志（仅 Debug 模式） */
+ (void)logProtocolReceive:(NSString *)tag protocol:(NSString *)protocol;

@end

NS_ASSUME_NONNULL_END
