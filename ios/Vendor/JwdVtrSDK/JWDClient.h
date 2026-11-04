//
//  JWDClient.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 主客户端类（单例模式）
//
//  功能概述:
//  - 录音控制：开始/停止录音、查询录音状态和信息
//  - 文件管理：浏览文件夹、下载/删除文件
//  - 设备管理：查询电量、存储容量、固件版本
//  - 设置管理：查询和修改设备设置项
//  - WiFi管理：WiFi通道切换、Socket文件传输
//  - 设备绑定：密钥验证、设备解绑
//  - OTA升级：固件升级功能
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

// Model
#import <JwdVtrSDK/JWDRecordState.h>
#import <JwdVtrSDK/JWDFileInfo.h>
#import <JwdVtrSDK/JWDWifiInfo.h>

// Delegates
#import <JwdVtrSDK/JWDBleConnectDelegate.h>
#import <JwdVtrSDK/JWDRecordStateDelegate.h>
#import <JwdVtrSDK/JWDFileMgrDelegate.h>
#import <JwdVtrSDK/JWDAuthDelegate.h>
#import <JwdVtrSDK/JWDBatteryDelegate.h>
#import <JwdVtrSDK/JWDDeviceInfoDelegate.h>
#import <JwdVtrSDK/JWDDeviceSettingDelegate.h>
#import <JwdVtrSDK/JWDWifiStatusDelegate.h>
#import <JwdVtrSDK/JWDSocketStatusDelegate.h>
#import <JwdVtrSDK/JWDOtaDelegate.h>
#import <JwdVtrSDK/JWDFileBkDelegate.h>
#import <JwdVtrSDK/JWDAudioDecoder.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * JWD VTR SDK 客户端主类
 * 提供统一的 SDK 访问入口，单例模式，线程安全
 */
@interface JWDClient : NSObject

/** 蓝牙连接状态委托 */
@property (nonatomic, weak, nullable) id<JWDBleConnectDelegate> bleConnectDelegate;

/** 录音状态委托 */
@property (nonatomic, weak, nullable) id<JWDRecordStateDelegate> recordStateDelegate;

/** 文件管理委托 */
@property (nonatomic, weak, nullable) id<JWDFileMgrDelegate> fileMgrDelegate;

/** 设备授权/绑定委托 */
@property (nonatomic, weak, nullable) id<JWDAuthDelegate> authDelegate;

/** 电池电量委托 */
@property (nonatomic, weak, nullable) id<JWDBatteryDelegate> batteryDelegate;

/** 设备信息委托 */
@property (nonatomic, weak, nullable) id<JWDDeviceInfoDelegate> deviceInfoDelegate;

/** 设备设置委托 */
@property (nonatomic, weak, nullable) id<JWDDeviceSettingDelegate> settingDelegate;

/** WiFi状态委托 */
@property (nonatomic, weak, nullable) id<JWDWifiStatusDelegate> wifiStatusDelegate;

/** Socket状态委托 */
@property (nonatomic, weak, nullable) id<JWDSocketStatusDelegate> socketStatusDelegate;

/** OTA升级委托 */
@property (nonatomic, weak, nullable) id<JWDOtaDelegate> otaDelegate;

/** 录音文件标记 (BK) 获取委托 */
@property (nonatomic, weak, nullable) id<JWDFileBkDelegate> fileBkDelegate;

/** 当前连接的蓝牙外设（只读） */
@property (nonatomic, strong, readonly, nullable) CBPeripheral *connectedPeripheral;

/** 蓝牙是否已连接 */
@property (nonatomic, assign, readonly) BOOL isBleConnected;

/** WiFi 是否已加速（Socket 已连接） */
@property (nonatomic, assign, readonly) BOOL isWifiAccelerated;

/**
 * 当前使用的音频解码器类型（MP3 / Opus），根据连接设备名自动判定。
 *
 * 默认值：未连接设备时为 JWDAudioDecoderTypeMP3。
 * 触发时机：BLE 连接成功后（onPeripheralConnected:），SDK 读取 CBPeripheral.name，
 *          若包含 "_P" 前缀（新型号录音笔）则切到 Opus；否则保持 MP3。
 */
@property (nonatomic, assign, readonly) JWDAudioDecoderType currentAudioDecoderType;

#pragma mark - 初始化

/**
 * 设置 SDK Debug 模式
 * 注意：生产环境请设置为 NO，避免泄露协议明文
 * @param enabled YES=开启Debug模式，NO=关闭Debug模式
 */
+ (void)setDebugMode:(BOOL)enabled;

/**
 * 获取单例实例
 * @return JWDClient 实例
 */
+ (instancetype)sharedInstance;

#pragma mark - 蓝牙连接

/**
 * 连接蓝牙外设
 * @param peripheral 扫描到的 CBPeripheral
 */
- (void)connectBt:(CBPeripheral *)peripheral;

/**
 * 断开蓝牙连接
 */
- (void)disConnect;

/**
 * 外部CBCentralManager在BLE连接成功后调用，触发服务发现
 * @param peripheral 已连接的 CBPeripheral
 */
- (void)onPeripheralConnected:(CBPeripheral *)peripheral;

/**
 * 外部CBCentralManager在BLE断开/连接失败时调用
 * @param peripheral 已断开的 CBPeripheral
 * @param error 断开原因（可为nil）
 */
- (void)onPeripheralDisconnected:(CBPeripheral *)peripheral error:(nullable NSError *)error;

#pragma mark - 录音控制

/** 开始录音 */
- (void)startRecord;

/** 停止录音 */
- (void)stopRecord;

/**
 * 暂停录音（发送 APP&PAU，MCU 应答 MCU&PAUSE 后回调 onRecordPaused）
 * 仅在录音过程中有效，非录音状态 MCU 会忽略或返回错误应答
 */
- (void)pauseRecord;

/**
 * 恢复录音（发送 APP&RESU，MCU 应答 MCU&RESUME 后回调 onRecordResumed）
 * 仅在已暂停的录音状态下有效
 */
- (void)resumeRecord;

/** 查询录音模式 (0=常规, 1=电话录音) */
- (void)getRecordMode;

/** 查询录音状态 (0=未录音, 1=录音中) */
- (void)getRecordStatus;

/** 查询当前录音信息（文件名、时长） */
- (void)getRecordInfo;

#pragma mark - 文件管理

/** 获取文件夹列表 */
- (void)getFileDirs;

/** 获取指定文件夹下的文件列表 */
- (void)getDirFiles:(NSString *)dir;

/** 导入/下载文件 */
- (void)importFile:(NSString *)dir fileName:(NSString *)fileName;

/** 取消文件传输 */
- (void)cancelImport;

/** 断点续传：从指定位置继续下载文件 */
- (void)resumeFile:(NSString *)dir fileName:(NSString *)fileName breakTime:(long)breakTime;

/** 删除设备上的指定文件 */
- (void)deleteFile:(NSString *)dir fileName:(NSString *)fileName;

/**
 * 获取录音文件对应的标记文件（发送 APP&BK&{dir}/{fileName}）
 *
 * MCU 收到后会通过音频 notify 通道将标记文件二进制内容（UTF-8 文本，每行一个整数）推送给 App，
 * SDK 内部累积并在 MCU 返回 MCU&BK&OK 时整体解码解析，
 * 通过 JWDFileBkDelegate 的 onFileBkReady:fileName:marks: 一次性回调整数列表。
 * 失败时回调 onFileBkError:fileName:errorCode:reason:（1=非空闲状态，2=该文件没有标记）。
 */
- (void)getFileBk:(NSString *)dir fileName:(NSString *)fileName;

/** 停止文件传输 */
- (void)stopFileTransfer;

#pragma mark - 设备信息

/** 获取电池电量 */
- (void)getBattery;

/** 查询存储容量 */
- (void)getCapacity;

/** 获取固件版本 */
- (void)getFwVersion;

/**
 * 获取设备 WiFi 模块版本号（杰理方案新增）
 * 发送 APP&WF，设备应答 MCU&WF&{version}（如 1.0），
 * 通过 JWDDeviceInfoDelegate 的 onDeviceWifiVersion: 回调
 */
- (void)getWifiVersion;

/**
 * 切换 Type-C USB 文件读取功能（杰理方案 V1.1）
 *
 * 发送 APP&USB&STA（STA: 1=开启, 0=关闭），
 * 设备应答 MCU&USB&STA 通过 JWDDeviceInfoDelegate 的 onUsbTransferStatus: 回调
 *
 * @param state 1=开启, 0=关闭
 */
- (void)setUsbTransferState:(int)state;

/**
 * 获取设备时间（杰理方案 V1.1）
 *
 * 发送 APP&GT，设备应答 MCU&CT&{yyyyMMddHHmmss}（如 20250909105012），
 * 通过 JWDDeviceInfoDelegate 的 onDeviceTime: 回调。
 *
 * @note 与 syncTime 互补：syncTime 是 APP→设备设时间；getDeviceTime 是查询设备当前时间。
 */
- (void)getDeviceTime;

/** 获取设备MAC地址 */
- (void)getDeviceMac;

/**
 * 获取设备 SN 号（同步返回，不下发蓝牙指令）
 *
 * SN 由当前连接蓝牙设备的名称解析得到，名称格式为「型号_SN」，
 * 例如 VTR7900_12345678901，下划线之后即为 SN 码。
 *
 * 解析规则：按下划线 "_" 分割设备名，取最后一段并去除首尾空白，
 * 只有长度恰好为 11 位时才视为有效 SN。
 *
 * @return 11 位 SN 字符串；未连接设备 / 设备名为空 / 名称不含下划线 /
 *         SN 长度不为 11 位时，均返回 nil
 */
- (nullable NSString *)getDeviceSN;

/**
 * 根据设备蓝牙名称判定音频解码类型（公开工具方法，调用方无需连接设备即可使用）。
 *
 * 判定规则：设备名包含 "_P" → Opus，否则 → MP3（与 Android 端对齐）。
 *
 * @param deviceName 蓝牙外设名（CBPeripheral.name），可为 nil/空
 * @return 解码类型
 */
+ (JWDAudioDecoderType)audioDecoderTypeForDeviceName:(nullable NSString *)deviceName;

/** 同步时间 */
- (void)syncTime;

#pragma mark - WiFi

/** 打开WiFi */
- (void)openWifi;

/** 关闭WiFi */
- (void)closeWifi;

/** 获取WiFi信息（SSID/密码） */
- (void)getWifiInfo;

/** 获取WiFi状态 */
- (void)getWifiStatus;

/** 切换到WiFi通道（停止蓝牙传输，开启WiFi） */
- (void)switchToWifiChannel;

/** 连接Socket（WiFi传输用） */
- (void)connectSocket;

#pragma mark - 设置管理

/** 获取支持的设置项列表 */
- (void)getSupportSettings;

/** 获取当前所有设置的值 */
- (void)getSettingStatus;

/** 设置单项的值 */
- (void)setSetting:(NSString *)key value:(NSString *)value;

#pragma mark - 其他

/** 格式化磁盘（删除所有数据，慎用） */
- (void)formatDisk;

/** 绑定设备（密钥验证） */
- (void)bindDevice:(NSString *)secret;

/** 解绑设备 */
- (void)unbindDevice;

#pragma mark - OTA

/** 开始OTA升级（旧接口，不携带 CRC32，兼容保留） */
- (void)startOTA:(long)fileSize;

/**
 * 开始OTA升级（杰理方案：携带固件包 CRC32）
 *
 * 发送 APP&OTA&{fileSize}&{crc32}；设备校验通过后回复 MCU&OTA（onOtaReceiveReady），
 * 随后按「每帧 256B、帧间隔 10ms、每 32 帧等 MCU&OTA&GO」的流控发送固件数据，
 * 全部发完调用 sendOTADataEnd（APP&OT&OVER）。
 *
 * @param fileSize 固件包字节数
 * @param crc32    固件包 CRC32（8 位十六进制字符串，如 @"FAFAFAFA"；传 nil 则退化为旧协议）
 */
- (void)startOTA:(long)fileSize crc32:(nullable NSString *)crc32;

/** 发送OTA数据帧（透传，SDK 不分帧；按协议每帧 256B） */
- (void)sendOTAData:(NSData *)data;

/** OTA数据发送完毕（发送 APP&OT&OVER） */
- (void)sendOTADataEnd;

/**
 * 主动终止 OTA 升级（杰理方案更新日志第 2 条）
 *
 * 发送 APP&OT&SHUT，设备回执 MCU&OT&ERR（无 VAL 字段），
 * 触发 onOtaTerminated 回调（区别于设备错误码 onOtaErrorWithCode:）。
 * 调用方应在 onOtaTerminated 中清空传输状态、关闭进度框，
 * 不用关心错误码语义。
 */
- (void)stopOTA;

#pragma mark - 释放

/** 释放SDK资源 */
- (void)releaseSDK;

@end

NS_ASSUME_NONNULL_END
