//
//  JWDBatteryDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 电量委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 充电状态（杰理协议 V1.1 充电上报解析）
 *
 * 协议形态：
 *   MCU&BAT&RATE       普通查询应答 / 拔掉充电器主动上报（RATE=200 哨兵值表示充电中）
 *   MCU&BAT&RATE&C     插入充电器主动上报（C 后缀 = 充电中，RATE 为真实百分比）
 *   MCU&BAT&100&F      充电完成主动上报（F 后缀 = 已充满）
 */
typedef NS_ENUM(NSInteger, JWDBatteryChargeStatus) {
    JWDBatteryChargeNone     = 0,  ///< 未充电（拔掉充电器 / 普通查询）
    JWDBatteryChargeCharging = 1,  ///< 充电中（C 后缀，或 RATE=200 哨兵值）
    JWDBatteryChargeFull     = 2,  ///< 已充满（MCU&BAT&100&F）
};

/**
 * 电量委托
 * 对应 Android 的 OnBatteryListener
 */
@protocol JWDBatteryDelegate <NSObject>

@optional

/**
 * 剩余百分比电量
 * @param level 剩余百分比 (0-100；协议哨兵值 200 原样透传，此时应以充电状态回调为准)
 */
- (void)onBatteryLevel:(int)level;

/**
 * 电量 + 充电状态上报（杰理协议 V1.1 新增）
 *
 * 所有 MCU&BAT& 形态（查询应答 / 插拔充电器主动上报 / 充满上报）都会触发本回调，
 * 应用层以此为准展示电量与充电图标；与 onBatteryLevel: 同时派发（旧回调兼容保留）。
 *
 * @param status 充电状态（见 JWDBatteryChargeStatus）
 * @param level  剩余百分比 (0-100)。
 *               注意：RATE=200 哨兵值场景 level 原样传 200（协议未定义此时真实电量），
 *               应用层在 status=Charging 时应以状态为准、不直接展示 level。
 */
- (void)onBatteryChargeStatus:(JWDBatteryChargeStatus)status level:(int)level;

@end

NS_ASSUME_NONNULL_END
