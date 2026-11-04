//
//  JWDWifiStatusDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - WiFi状态委托协议
//

#import <Foundation/Foundation.h>
#import <JwdVtrSDK/JWDWifiInfo.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * WiFi状态委托
 * 对应 Android 的 OnWifiStatusListener
 *
 * WiFi状态码说明:
 *  0 = WiFi关闭
 *  1 = WiFi已连接
 *  2 = WiFi未连接
 *  3 = 等待WiFi开启
 *  4 = 修改密码中
 *  5 = OTA升级中
 *  6 = 密码修改成功，等待系统复位关机
 *  7 = 自动关闭
 *  8 = WiFi传输已开启
 */
@protocol JWDWifiStatusDelegate <NSObject>

@optional

/**
 * WiFi 状态变化
 * @param status 状态码
 */
- (void)onWifiStatus:(int)status;

/**
 * WiFi 配置信息（SSID和密码）
 * @param wifiInfo WiFi信息
 */
- (void)onWifiInfo:(JWDWifiInfo *)wifiInfo;

@end

NS_ASSUME_NONNULL_END
