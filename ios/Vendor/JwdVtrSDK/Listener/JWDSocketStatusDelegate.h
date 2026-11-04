//
//  JWDSocketStatusDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - Socket状态委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Socket 连接状态委托（WiFi传输用）
 * 对应 Android 的 OnSocketStatusListener
 */
@protocol JWDSocketStatusDelegate <NSObject>

@optional

/** 连接成功 */
- (void)onSocketConnected;

/**
 * 连接失败
 * @param error 错误信息
 */
- (void)onSocketConnectFailed:(NSString *)error;

/**
 * 断开连接
 * @param reason 断开原因
 */
- (void)onSocketDisconnected:(NSString *)reason;

/**
 * 发生错误
 * @param error     错误信息
 * @param exception 异常对象
 */
- (void)onSocketError:(NSString *)error exception:(nullable NSException *)exception;

@end

NS_ASSUME_NONNULL_END
