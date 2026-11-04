//
//  JWDReplyParser.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 协议响应解析类
//

#import <Foundation/Foundation.h>
#import "JWDBleConnectDelegate.h"
#import "JWDRecordStateDelegate.h"
#import "JWDFileMgrDelegate.h"
#import "JWDAuthDelegate.h"
#import "JWDBatteryDelegate.h"
#import "JWDDeviceInfoDelegate.h"
#import "JWDDeviceSettingDelegate.h"
#import "JWDWifiStatusDelegate.h"
#import "JWDSocketStatusDelegate.h"
#import "JWDOtaDelegate.h"
#import "JWDFileBkDelegate.h"
#import "JWDSocketClient.h"
#import "JWDAudioDecoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface JWDReplyParser : NSObject <JWDSocketClientCallback>

/** 发送命令回调块（用于 WiFi 状态轮询等需要主动发送命令的场景） */
@property (nonatomic, copy, nullable) void(^sendCommandBlock)(NSString *command);

// 委托属性
@property (nonatomic, weak, nullable) id<JWDRecordStateDelegate> recordStateDelegate;
@property (nonatomic, weak, nullable) id<JWDFileMgrDelegate> fileMgrDelegate;
@property (nonatomic, weak, nullable) id<JWDAuthDelegate> authDelegate;
@property (nonatomic, weak, nullable) id<JWDBatteryDelegate> batteryDelegate;
@property (nonatomic, weak, nullable) id<JWDDeviceInfoDelegate> deviceInfoDelegate;
@property (nonatomic, weak, nullable) id<JWDDeviceSettingDelegate> settingDelegate;
@property (nonatomic, weak, nullable) id<JWDWifiStatusDelegate> wifiStatusDelegate;
@property (nonatomic, weak, nullable) id<JWDSocketStatusDelegate> socketStatusDelegate;
@property (nonatomic, weak, nullable) id<JWDOtaDelegate> otaDelegate;
@property (nonatomic, weak, nullable) id<JWDFileBkDelegate> fileBkDelegate;

// 状态
@property (nonatomic, assign, readonly) BOOL isAuth;
@property (nonatomic, assign) int importingFile; // 0=未导入, 1=BLE, 2=WiFi

// 当前操作相关
@property (nonatomic, copy, nullable) NSString *currentDownloadFile;
@property (nonatomic, copy, nullable) NSString *currentDir;
@property (nonatomic, copy, nullable) NSString *currentDelFileName;
@property (nonatomic, copy, nullable) NSString *currentResumeFile;
@property (nonatomic, copy, nullable) NSString *currentSettingName;

/**
 * 解析从设备接收到的蓝牙指令数据
 * @param hexString 16进制空格分隔的字符串
 */
- (void)parseMessage:(NSString *)hexString;

/**
 * 处理从音频特征通道接收到的音频数据
 * @param data 原始音频字节数据
 */
- (void)postAudioData:(NSData *)data;

/**
 * 进入 BK（标记文件）接收状态（App 发送 APP&BK&{dir}/{fileName} 前调用）
 *
 * 必须在发送协议前调用，确保协议往返窗口内到达的音频帧也能被正确路由到 BK 缓冲区，
 * 避免被录音 / BLE 文件下载分支误处理（对齐 Android ReplyParser.startFileBk）。
 * @param dir      录音文件所在文件夹名
 * @param fileName 录音文件名
 */
- (void)startFileBk:(NSString *)dir fileName:(NSString *)fileName;

/** WiFi 是否已加速（socket 已连接） */
@property (nonatomic, assign, readonly) BOOL isWifiAccelerated;

/** WiFi 加速是否由用户主动发起（用于区分设备自动开启 WiFi 和用户主动加速） */
@property (nonatomic, assign) BOOL isWifiAccelerationUserInitiated;

/** 连接Socket（WiFi传输用） */
- (void)connectSocket;

/** 断开Socket连接 */
- (void)disconnectSocket;

/** 关闭 WiFi 加速会话（断开 Socket + 断开热点 + 停止轮询 + 重置状态） */
- (void)closeWifiSession;

/** 开始 WiFi 状态轮询（WiFi 打开后调用） */
- (void)startWifiStatusQuery;

/** 停止 WiFi 状态轮询 */
- (void)stopWifiStatusQuery;

/** 重置状态（蓝牙断开时调用） */
- (void)reset;

/** 释放资源 */
- (void)releaseResources;

#pragma mark - 音频解码器路由

/**
 * 当前正在使用的音频解码类型（MP3 / Opus）。
 * 默认 MP3；蓝牙连接时由 JWDClient 根据设备名自动设置。
 */
@property (nonatomic, assign, readonly) JWDAudioDecoderType currentAudioDecoderType;

/**
 * 配置音频解码器类型。
 *
 * 调用时机：
 *   - JWDClient 在 onPeripheralConnected: 时根据设备名自动调用（推荐）。
 *   - 也可在蓝牙断开后、再次录音前手动切换。
 *
 * 实现细节：
 *   - 若当前正在录音（audioDecoder.isRunning == YES），先 stop 旧解码器；
 *   - 切换 _audioDecoder 指向对应实现（MP3 / Opus）；
 *   - 旧解码器实例仍保留，便于切回。
 *
 * @param type 解码器类型
 */
- (void)configureWithAudioDecoderType:(JWDAudioDecoderType)type;

@end

NS_ASSUME_NONNULL_END
