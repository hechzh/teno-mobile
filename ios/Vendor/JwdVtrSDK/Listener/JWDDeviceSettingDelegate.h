//
//  JWDDeviceSettingDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 设备设置委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 设备设置委托
 * 对应 Android 的 OnDeviceSettingListener
 */
@protocol JWDDeviceSettingDelegate <NSObject>

@optional

/**
 * 支持的设置项列表
 * @param supportSettings 设置项名称列表
 */
- (void)onSettingList:(NSArray<NSString *> *)supportSettings;

/**
 * 每个设置的当前状态值
 * @param status 设置名-值映射
 */
- (void)onSettingStatus:(NSDictionary<NSString *, NSNumber *> *)status;

/**
 * 设置指令执行成功
 * @param settingName 设置项名称
 */
- (void)onSetSuccess:(NSString *)settingName;

/** 时间同步成功 */
- (void)onTimeSyncSuccess;

@end

NS_ASSUME_NONNULL_END
