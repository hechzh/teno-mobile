//
//  JWDRecordStateDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 录音状态委托协议
//

#import <Foundation/Foundation.h>
#import <JwdVtrSDK/JWDRecordState.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 录音状态委托
 * 对应 Android 的 OnRecordStateListener
 */
@protocol JWDRecordStateDelegate <NSObject>

@optional

/**
 * 录音操作指令的回调
 * @param state       录音状态
 * @param fileName    文件名
 * @param currentTime 只有当BLE连接前设备已经开启录音时会有，单位是秒
 */
- (void)onRecordStateReply:(JWDRecordState)state fileName:(nullable NSString *)fileName currentTime:(long)currentTime;

/**
 * 录音查询指令的回调
 * @param status 0表示未录音，1表示录音中
 */
- (void)onRecordStateCheck:(int)status;

/**
 * 开始录音的实时音频流（PCM 数据，16-bit Signed Integer Little-Endian）
 * SDK 内部已将设备传输的 MP3 裸流解码为 PCM（对齐 Android MediaCodec 行为）
 * @param data PCM 数据流
 */
- (void)onRecordStream:(NSData *)data;

/**
 * 录音模式
 * @param mode 0表示常规录音，1表示电话录音
 */
- (void)onRecordMode:(int)mode;

/**
 * MCU 确认已暂停录音（对应协议 MCU&PAUSE，App 侧由 pauseRecord 发送 APP&PAU）
 */
- (void)onRecordPaused;

/**
 * MCU 确认已恢复录音（对应协议 MCU&RESUME，App 侧由 resumeRecord 发送 APP&RESU）
 */
- (void)onRecordResumed;

@end

NS_ASSUME_NONNULL_END
