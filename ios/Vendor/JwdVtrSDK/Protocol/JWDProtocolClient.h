//
//  JWDProtocolClient.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 蓝牙协议发送类
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface JWDProtocolClient : NSObject

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral
                  writeCharact:(CBCharacteristic *)writeCharact;

/** 发送文本命令（自动编码） */
- (void)sendCommand:(NSString *)command;

/** 发送原始字节数据 */
- (void)sendRawData:(NSData *)data;

// === 录音控制 ===
- (void)startRecord;
- (void)stopRecord;
- (void)pauseRecord;
- (void)resumeRecord;
- (void)getRecordStatus;
- (void)getRecordMode;
- (void)getRecordInfo;

// === 文件管理 ===
- (void)getFileDirs;
- (void)getDirFiles:(NSString *)dir;
- (void)importFile:(NSString *)dir fileName:(NSString *)fileName;
- (void)resumeFile:(NSString *)dir filename:(NSString *)filename breakTime:(long)breakTime;
- (void)cancelImport;
- (void)stopFileTransfer;
- (void)deleteFile:(NSString *)dir fileName:(NSString *)fileName;

/**
 * 获取录音文件对应的标记文件
 * 发送命令: APP&BK&{dir}/{fileName}（注意：dir 与 fileName 之间用 "/" 分隔）
 */
- (void)getFileBk:(NSString *)dir fileName:(NSString *)fileName;

// === 设备信息 ===
- (void)getBattery;
- (void)getCapacity;
- (void)getFwVersion;
- (void)getWifiVersion;
- (void)getDeviceMac;
- (void)syncTime;

/**
 * 获取设备时间（杰理方案 V1.1）
 * 发送 APP&GT，设备应答 MCU&CT&{yyyyMMddHHmmss}，
 * 通过 JWDDeviceInfoDelegate 的 onDeviceTime: 回调
 */
- (void)getDeviceTime;

/**
 * 切换 Type-C USB 文件读取功能（杰理方案 V1.1）
 * 发送 APP&USB&STA，STA: 1=开启, 0=关闭
 * 设备回执 MCU&USB&STA 通过 JWDDeviceInfoDelegate.onUsbTransferStatus: 派发
 */
- (void)setUsbTransferState:(int)state;

// === WiFi ===
- (void)openWifi;
- (void)closeWifi;
- (void)getWifiInfo;
- (void)getWifiStatus;
- (void)switchSocketSend;

// === 设置 ===
- (void)getSupportSettings;
- (void)getSettingStatus;
- (void)setSetting:(NSString *)key value:(NSString *)value;

// === 其他 ===
- (void)formatDisk;
- (void)bindDevice:(NSString *)secret;
- (void)unbindDevice;

// === OTA ===
- (void)startOTA:(long)len;

/**
 * 开始 OTA 升级（杰理方案：携带固件包 CRC32 校验码）
 * 发送命令: APP&OTA&{len}&{crc32}
 * @param len   固件包字节数
 * @param crc32 固件包 CRC32（8 位十六进制字符串，如 @"FAFAFAFA"）
 */
- (void)startOTA:(long)len crc32:(NSString *)crc32;

- (void)sendOTAData:(NSData *)data;
- (void)sendOTADataEnd;

/**
 * 主动终止 OTA 升级（杰理方案更新日志第 2 条新增）
 *
 * 发送 APP&OT&SHUT，设备确认后回 MCU&OT&ERR（无 VAL 字段），
 * 触发 onOtaTerminated 回调（区分于设备错误码回调 onOtaErrorWithCode:）。
 * 适合用户主动取消场景：调用后清空传输状态，UI 可立即关闭进度框。
 */
- (void)stopOTA;

@end

NS_ASSUME_NONNULL_END
