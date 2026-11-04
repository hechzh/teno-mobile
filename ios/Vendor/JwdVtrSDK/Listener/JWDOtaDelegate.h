//
//  JWDOtaDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - OTA升级委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * OTA 升级错误码
 *
 * -1 ~ 3：设备端错误码（MCU&OT&ERR&VAL 上报，杰理方案）
 * 100+：SDK 本地生成（不来自设备），用于区分错误来源
 */
typedef NS_ENUM(NSInteger, JWDOtaErrorCode) {
    // === 设备端错误码（MCU&OT&ERR&VAL）===
    JWDOtaErrorUnknown        = -1,  ///< 未知异常（VAL 缺省时）
    JWDOtaErrorFileSize       = 0,   ///< 固件包大小异常
    JWDOtaErrorVersion        = 1,   ///< 固件包版本小于或等于当前版本
    JWDOtaErrorLowBattery     = 2,   ///< 低电量异常
    JWDOtaErrorTimeout        = 3,   ///< 机器端 OTA 超时

    // === SDK 本地错误码（应用层主动行为，非设备上报）===
    JWDOtaErrorCancelledByUser = 100, ///< 应用层主动取消（stopOTA / APP&OT&SHUT 后设备回执 ERR）
};

/**
 * OTA 升级委托
 * 对应 Android 的 OnOtaListener
 */
@protocol JWDOtaDelegate <NSObject>

@optional

/** 设备准备好接收OTA数据（应答 APP&OTA&LEN&CRC32 的 MCU&OTA） */
- (void)onOtaReceiveReady;

/**
 * 设备确认继续发送（MCU&OTA&GO，杰理方案新增）
 *
 * 流控规则：App 每发送 32 帧（每帧 256B、帧间隔 10ms）需暂停，
 * 收到本回调后方可继续发送下一组 32 帧。
 */
- (void)onOtaGo;

/**
 * 接收帧索引确认
 * @param index 帧索引
 */
- (void)onOtaFrameIndex:(int)index;

/** OTA数据接收结束，升级完成（MCU&OT&OVER，固件包完整接收） */
- (void)onOtaReceiveEnd;

/**
 * OTA 升级失败（唯一错误出口，必选实现）
 *
 * 所有失败路径统一经本回调派发，errorCode 标明来源：
 *   - 设备上报错误（MCU&OT&ERR&VAL）：JWDOtaErrorUnknown(-1) ~ JWDOtaErrorTimeout(3)
 *   - 应用层主动取消（stopOTA 后设备回执 ERR）：JWDOtaErrorCancelledByUser(100)
 *
 * 应用层按 errorCode 分支处理；用户主动取消场景（100）不应弹"升级失败"类提示。
 *
 * @param errorCode 错误码（见 JWDOtaErrorCode）
 */
- (void)onOtaErrorWithCode:(JWDOtaErrorCode)errorCode;

@end

NS_ASSUME_NONNULL_END
