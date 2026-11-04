//
//  JWDDeviceInfoDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 设备信息委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 设备信息委托
 * 对应 Android 的 OnDeviceInfoListener
 */
@protocol JWDDeviceInfoDelegate <NSObject>

@optional

/**
 * 设备 MAC 地址
 * @param mac MAC 地址字符串
 */
- (void)onDeviceMac:(NSString *)mac;

/**
 * 存储容量
 * @param remain   剩余容量 (MB)
 * @param capacity 总容量 (MB)
 */
- (void)onDeviceCapacity:(int)remain capacity:(int)capacity;

/**
 * 固件版本号
 * @param version 版本号字符串
 */
- (void)onDeviceFirmwareVersion:(NSString *)version;

/**
 * 设备 WiFi 模块版本号（杰理方案新增）
 * 应答 getWifiVersion（APP&WF）的 MCU&WF&{version}，如 @"1.0"
 * @param version WiFi 模块版本号字符串
 */
- (void)onDeviceWifiVersion:(NSString *)version;

/**
 * 设备 Type-C USB 数据传输状态（杰理方案 V1.1）
 *
 * 发送 setUsbTransferState: 后，设备通过 MCU&USB&STA&{1|0} 应答；
 * STATE: 1=已开启, 0=已关闭。
 *
 * @param state 1=开启, 0=关闭
 */
- (void)onUsbTransferStatus:(int)state;

/**
 * 设备时间（杰理方案 V1.1）
 *
 * 发送 getDeviceTime（APP&GT）后，设备通过 MCU&CT&{yyyyMMddHHmmss} 应答。
 * 时间格式 yyyyMMddHHmmss（如 @"20250909105012"），与 syncTime 发送格式一致。
 *
 * @param time 设备时间字符串（14 位 yyyyMMddHHmmss）；应答缺段时为空串
 */
- (void)onDeviceTime:(NSString *)time;

@end

NS_ASSUME_NONNULL_END
