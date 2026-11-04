//
//  JWDAuthDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 设备授权委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 设备授权/绑定委托
 * 对应 Android 的 OnAuthListener
 */
@protocol JWDAuthDelegate <NSObject>

@optional

/** 密钥验证成功，设备绑定成功 */
- (void)onAuthSuccess;

/** 密钥验证失败，绑定失败 */
- (void)onAuthFailed;

@end

NS_ASSUME_NONNULL_END
