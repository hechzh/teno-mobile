//
//  JWDBleConnectDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 蓝牙连接委托协议
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 蓝牙连接状态委托
 * 对应 Android 的 OnBleConnectListener
 */
@protocol JWDBleConnectDelegate <NSObject>

@optional

/** 开始扫描 */
- (void)onBleStart;

/**
 * 连接错误
 * @param errorCode 错误码
 */
- (void)onBleError:(int)errorCode;

/**
 * 连接成功
 * @param peripheral 已连接的蓝牙外设
 */
- (void)onBleConnected:(CBPeripheral *)peripheral;

/**
 * 断开连接
 * @param peripheral 已断开的蓝牙外设
 */
- (void)onBleDisConnected:(CBPeripheral *)peripheral;

@end

NS_ASSUME_NONNULL_END
