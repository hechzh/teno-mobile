//
//  JWDClient.m
//  JwdVtrSDK
//

#import "JWDClient.h"
#import "JWDProtocolClient.h"
#import "JWDReplyParser.h"
#import "JWDSdkLogger.h"
#import "JWDTool.h"

static NSString *const TAG = @"JWDClient";

// BLE Service & Characteristic UUIDs
static NSString *const kServiceUUID       = @"001120A0-2233-4455-6677-889912345678";
static NSString *const kNotifyAudioUUID   = @"001120A1-2233-4455-6677-889912345678";
static NSString *const kWriteUUID         = @"001120A2-2233-4455-6677-889912345678";
static NSString *const kNotifyCmdUUID     = @"001120A3-2233-4455-6677-889912345678";

// 设备 SN 码固定长度（从蓝牙设备名「型号_SN」中解析）
static const NSUInteger kJWDDeviceSNLength = 11;

// static const int MAX_RETRY_COUNT = 3;

@interface JWDClient () <CBPeripheralDelegate, JWDOtaDelegate>

@property (nonatomic, strong, readwrite, nullable) CBPeripheral *connectedPeripheral;
@property (nonatomic, assign, readwrite) BOOL isBleConnected;

@property (nonatomic, strong, nullable) JWDProtocolClient *protocolClient;
@property (nonatomic, strong) JWDReplyParser *replyParser;
@property (nonatomic, strong, nullable) CBCharacteristic *writeCharact;
@property (nonatomic, strong) NSMutableArray<CBCharacteristic *> *notifyCharList;
@property (nonatomic, assign) int notifyIndex;
@property (nonatomic, assign) int connectRetryCount;
// OTA 用户主动取消标志：stopOTA 置 YES；onOtaErrorWithCode: 派发前检查，
// 区分"用户取消产生的 ERR"与"设备真正的错误 ERR"。
@property (nonatomic, assign) BOOL otaUserCancelled;
// 临时保存应用层原 otaDelegate：stopOTA 时改指 self 拦截 ERR 派发，
// 处理完毕恢复。
@property (nonatomic, weak, nullable) id<JWDOtaDelegate> otaDelegateBeforeCancel;

@end

@implementation JWDClient

#pragma mark - 单例

+ (instancetype)sharedInstance {
    static JWDClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JWDClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _replyParser = [[JWDReplyParser alloc] init];
        _notifyCharList = [NSMutableArray array];
        _isBleConnected = NO;
        _connectRetryCount = 0;
    }
    return self;
}

+ (void)setDebugMode:(BOOL)enabled {
    [JWDSdkLogger setDebugEnabled:enabled];
}

- (BOOL)isWifiAccelerated {
    return self.replyParser.isWifiAccelerated;
}

- (JWDAudioDecoderType)currentAudioDecoderType {
    return self.replyParser.currentAudioDecoderType;
}

+ (JWDAudioDecoderType)audioDecoderTypeForDeviceName:(NSString *)deviceName {
    return JWDAudioDecoderTypeForDeviceName(deviceName);
}

#pragma mark - 委托转发设置

- (void)setRecordStateDelegate:(id<JWDRecordStateDelegate>)recordStateDelegate {
    _recordStateDelegate = recordStateDelegate;
    self.replyParser.recordStateDelegate = recordStateDelegate;
}

- (void)setFileMgrDelegate:(id<JWDFileMgrDelegate>)fileMgrDelegate {
    _fileMgrDelegate = fileMgrDelegate;
    self.replyParser.fileMgrDelegate = fileMgrDelegate;
}

- (void)setAuthDelegate:(id<JWDAuthDelegate>)authDelegate {
    _authDelegate = authDelegate;
    self.replyParser.authDelegate = authDelegate;
}

- (void)setBatteryDelegate:(id<JWDBatteryDelegate>)batteryDelegate {
    _batteryDelegate = batteryDelegate;
    self.replyParser.batteryDelegate = batteryDelegate;
}

- (void)setDeviceInfoDelegate:(id<JWDDeviceInfoDelegate>)deviceInfoDelegate {
    _deviceInfoDelegate = deviceInfoDelegate;
    self.replyParser.deviceInfoDelegate = deviceInfoDelegate;
}

- (void)setSettingDelegate:(id<JWDDeviceSettingDelegate>)settingDelegate {
    _settingDelegate = settingDelegate;
    self.replyParser.settingDelegate = settingDelegate;
}

- (void)setWifiStatusDelegate:(id<JWDWifiStatusDelegate>)wifiStatusDelegate {
    _wifiStatusDelegate = wifiStatusDelegate;
    self.replyParser.wifiStatusDelegate = wifiStatusDelegate;
}

- (void)setSocketStatusDelegate:(id<JWDSocketStatusDelegate>)socketStatusDelegate {
    _socketStatusDelegate = socketStatusDelegate;
    self.replyParser.socketStatusDelegate = socketStatusDelegate;
}

- (void)setOtaDelegate:(id<JWDOtaDelegate>)otaDelegate {
    _otaDelegate = otaDelegate;
    self.replyParser.otaDelegate = otaDelegate;
    // 重置取消标志（场景：上次 cancel 走完 ERR 后，再开始新一轮 OTA）
    self.otaUserCancelled = NO;
}

- (void)setFileBkDelegate:(id<JWDFileBkDelegate>)fileBkDelegate {
    _fileBkDelegate = fileBkDelegate;
    self.replyParser.fileBkDelegate = fileBkDelegate;
}

#pragma mark - 蓝牙连接

- (void)connectBt:(CBPeripheral *)peripheral {
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"正在连接: %@", peripheral.identifier.UUIDString]];
    
    self.connectedPeripheral = peripheral;
    peripheral.delegate = self;
    
    // 通知开始扫描
    if (self.bleConnectDelegate && [self.bleConnectDelegate respondsToSelector:@selector(onBleStart)]) {
        [self.bleConnectDelegate onBleStart];
    }
    
    // iOS中由CBCentralManager发起连接，这里保存peripheral并等待外部调用
    // 实际上连接由CBCentralManager完成，连接成功后调用此方法设置delegate
}

- (void)disConnect {
    if (self.connectedPeripheral) {
        CBPeripheral *device = self.connectedPeripheral;
        self.connectedPeripheral = nil;
        self.protocolClient = nil;
        self.isBleConnected = NO;
        self.writeCharact = nil;
        [self.notifyCharList removeAllObjects];
        
        self.replyParser.sendCommandBlock = nil;
        [self.replyParser reset];
        
        [JWDSdkLogger d:TAG msg:@"断开连接"];
        
        if (self.bleConnectDelegate && [self.bleConnectDelegate respondsToSelector:@selector(onBleDisConnected:)]) {
            [self.bleConnectDelegate onBleDisConnected:device];
        }
    }
}

/**
 * 由外部CBCentralManager在连接成功后调用，开始发现服务
 */
- (void)onPeripheralConnected:(CBPeripheral *)peripheral {
    self.connectedPeripheral = peripheral;
    peripheral.delegate = self;
    self.connectRetryCount = 0;

    // 根据设备名自动选择音频解码器（MP3 / Opus）
    // 判定规则：设备名含 "_P" → Opus，否则 → MP3（与 Android 端对齐）
    JWDAudioDecoderType type = [[self class] audioDecoderTypeForDeviceName:peripheral.name];
    [self.replyParser configureWithAudioDecoderType:type];
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"BLE 连接设备: %@, 自动选择音频解码器: %@",
                              peripheral.name ?: @"(无名称)",
                              type == JWDAudioDecoderTypeOpus ? @"Opus" : @"MP3"]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
    });
}

/**
 * 由外部CBCentralManager在连接失败/断开时调用
 */
- (void)onPeripheralDisconnected:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    [JWDSdkLogger i:TAG msg:@"蓝牙连接断开"];
    
    self.replyParser.sendCommandBlock = nil;
    [self.replyParser reset];
    self.protocolClient = nil;
    self.writeCharact = nil;
    [self.notifyCharList removeAllObjects];
    self.isBleConnected = NO;
    self.connectedPeripheral = nil;
    
    if (self.bleConnectDelegate && [self.bleConnectDelegate respondsToSelector:@selector(onBleDisConnected:)]) {
        [self.bleConnectDelegate onBleDisConnected:peripheral];
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"发现服务失败: %@", error.localizedDescription]];
        if (self.bleConnectDelegate && [self.bleConnectDelegate respondsToSelector:@selector(onBleError:)]) {
            [self.bleConnectDelegate onBleError:(int)error.code];
        }
        return;
    }
    
    [JWDSdkLogger i:TAG msg:@"发现服务"];
    
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            [peripheral discoverCharacteristics:@[
                [CBUUID UUIDWithString:kNotifyAudioUUID],
                [CBUUID UUIDWithString:kWriteUUID],
                [CBUUID UUIDWithString:kNotifyCmdUUID]
            ] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"发现特征失败: %@", error.localizedDescription]];
        if (self.bleConnectDelegate && [self.bleConnectDelegate respondsToSelector:@selector(onBleError:)]) {
            [self.bleConnectDelegate onBleError:(int)error.code];
        }
        return;
    }
    
    [self.notifyCharList removeAllObjects];
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSString *uuid = characteristic.UUID.UUIDString;
        [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"发现特征: %@", uuid]];
        
        if ([uuid caseInsensitiveCompare:kWriteUUID] == NSOrderedSame) {
            self.writeCharact = characteristic;
        } else if ([uuid caseInsensitiveCompare:kNotifyAudioUUID] == NSOrderedSame ||
                   [uuid caseInsensitiveCompare:kNotifyCmdUUID] == NSOrderedSame) {
            [self.notifyCharList addObject:characteristic];
        }
    }
    
    self.notifyIndex = 0;
    if (self.notifyCharList.count > 0) {
        [peripheral setNotifyValue:YES forCharacteristic:self.notifyCharList[0]];
        self.notifyIndex = 1;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"通知设置失败: %@", error.localizedDescription]];
        return;
    }
    
    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"通知设置成功: %@", characteristic.UUID.UUIDString]];
    
    if (self.notifyIndex < (int)self.notifyCharList.count) {
        [peripheral setNotifyValue:YES forCharacteristic:self.notifyCharList[self.notifyIndex]];
        self.notifyIndex++;
    }
    
    if (self.notifyIndex >= (int)self.notifyCharList.count) {
        // 所有通知特征设置完成，连接成功
        [JWDSdkLogger i:TAG msg:@"BLE连接成功"];
        
        self.protocolClient = [[JWDProtocolClient alloc] initWithPeripheral:peripheral
                                                              writeCharact:self.writeCharact];
        self.isBleConnected = YES;
        
        // 设置发送命令回调，用于 WiFi 状态轮询等场景
        __weak JWDProtocolClient *weakProtocolClient = self.protocolClient;
        self.replyParser.sendCommandBlock = ^(NSString *command) {
            [weakProtocolClient sendCommand:command];
        };
        
        if (self.bleConnectDelegate && [self.bleConnectDelegate respondsToSelector:@selector(onBleConnected:)]) {
            [self.bleConnectDelegate onBleConnected:peripheral];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error || !characteristic.value) return;
    
    NSString *uuid = characteristic.UUID.UUIDString;
    
    if ([uuid caseInsensitiveCompare:kNotifyAudioUUID] == NSOrderedSame) {
        // 音频数据通道
        [self.replyParser postAudioData:characteristic.value];
    } else {
        // 指令数据通道
        NSString *hexStr = [JWDTool dataToHexString:characteristic.value];
        [self.replyParser parseMessage:hexStr];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"写入特征失败: %@", error.localizedDescription]];
    }
}

- (void)peripheralIsReadyToUpdateSubscribedData:(CBPeripheral *)peripheral {
    [JWDSdkLogger d:TAG msg:@"外设准备好接收数据"];
}

#pragma mark - 录音控制

- (void)startRecord {
    if (self.protocolClient) {
        [self.protocolClient startRecord];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)stopRecord {
    if (self.protocolClient) {
        [self.protocolClient stopRecord];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)pauseRecord {
    if (self.protocolClient) {
        [self.protocolClient pauseRecord];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)resumeRecord {
    if (self.protocolClient) {
        [self.protocolClient resumeRecord];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getRecordMode {
    if (self.protocolClient) {
        [self.protocolClient getRecordMode];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getRecordStatus {
    if (self.protocolClient) {
        [self.protocolClient getRecordStatus];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getRecordInfo {
    if (self.protocolClient) {
        [self.protocolClient getRecordInfo];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

#pragma mark - 文件管理

- (void)getFileDirs {
    if (self.protocolClient) {
        [self.protocolClient getFileDirs];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getDirFiles:(NSString *)dir {
    if (self.protocolClient) {
        [self.protocolClient getDirFiles:dir];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)importFile:(NSString *)dir fileName:(NSString *)fileName {
    if (self.protocolClient) {
        self.replyParser.currentDownloadFile = fileName;
        self.replyParser.currentDir = dir;
        [self.protocolClient importFile:dir fileName:fileName];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)cancelImport {
    if (self.protocolClient) {
        [self.protocolClient cancelImport];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)resumeFile:(NSString *)dir fileName:(NSString *)fileName breakTime:(long)breakTime {
    if (self.protocolClient) {
        self.replyParser.currentResumeFile = fileName;
        // 续传走的是同一条 MCU&U&len 起始流程：若不设置 currentDownloadFile，
        // 传输过程中透传给应用层的 fileName 会沿用上一次普通导入的文件名（历史缺陷），
        // 终结日志里的 file= 也会张冠李戴。这里一并修正。
        self.replyParser.currentDownloadFile = fileName;
        self.replyParser.currentDir = dir;
        [self.protocolClient resumeFile:dir filename:fileName breakTime:breakTime];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)deleteFile:(NSString *)dir fileName:(NSString *)fileName {
    if (self.protocolClient) {
        self.replyParser.currentDelFileName = fileName;
        [self.protocolClient deleteFile:dir fileName:fileName];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getFileBk:(NSString *)dir fileName:(NSString *)fileName {
    if (!self.protocolClient) {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
        return;
    }
    // 提前进入 BK 接收状态（发送协议前），避免协议往返窗口内 MCU 已推送的音频帧
    // 被路由到录音 / 文件下载分支（对齐 Android JwdClient.getFileBk 调度顺序）
    [self.replyParser startFileBk:dir fileName:fileName];
    [self.protocolClient getFileBk:dir fileName:fileName];
}

- (void)stopFileTransfer {
    if (self.protocolClient) {
        [self.protocolClient stopFileTransfer];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

#pragma mark - 设备信息

- (void)getBattery {
    if (self.protocolClient) {
        [self.protocolClient getBattery];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getCapacity {
    if (self.protocolClient) {
        [self.protocolClient getCapacity];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getFwVersion {
    if (self.protocolClient) {
        [self.protocolClient getFwVersion];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getWifiVersion {
    if (self.protocolClient) {
        [self.protocolClient getWifiVersion];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)setUsbTransferState:(int)state {
    if (self.protocolClient) {
        [self.protocolClient setUsbTransferState:state];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getDeviceTime {
    if (self.protocolClient) {
        [self.protocolClient getDeviceTime];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getDeviceMac {
    if (self.protocolClient) {
        [self.protocolClient getDeviceMac];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (nullable NSString *)getDeviceSN {
    NSString *deviceName = self.connectedPeripheral.name;
    if (deviceName.length == 0) {
        [JWDSdkLogger e:TAG msg:@"获取SN失败：当前无已连接的蓝牙设备或设备名为空"];
        return nil;
    }

    // 设备名格式：型号_SN（如 VTR7900_12345678901），按下划线分割后取最后一段
    NSArray<NSString *> *components = [deviceName componentsSeparatedByString:@"_"];
    if (components.count < 2) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"获取SN失败：设备名不含下划线分隔符 -> %@", deviceName]];
        return nil;
    }

    NSString *sn = [components.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (sn.length != kJWDDeviceSNLength) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"获取SN失败：SN应为%lu位，实际%lu位 -> %@",
                                  (unsigned long)kJWDDeviceSNLength, (unsigned long)sn.length, deviceName]];
        return nil;
    }

    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"解析到设备SN: %@", sn]];
    return sn;
}

- (void)syncTime {
    if (self.protocolClient) {
        [self.protocolClient syncTime];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

#pragma mark - WiFi

- (void)openWifi {
    if (self.protocolClient) {
        self.replyParser.isWifiAccelerationUserInitiated = YES;
        [self.protocolClient openWifi];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)closeWifi {
    // 完整清理 WiFi 加速会话：断 Socket + 断热点 + 停轮询 + 重置状态
    [self.replyParser closeWifiSession];
    // 通知设备关闭 WiFi
    if (self.protocolClient) {
        [self.protocolClient closeWifi];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getWifiInfo {
    if (self.protocolClient) {
        [self.protocolClient getWifiInfo];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getWifiStatus {
    if (self.protocolClient) {
        [self.protocolClient getWifiStatus];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)switchToWifiChannel {
    if (self.protocolClient) {
        [self.protocolClient stopFileTransfer];
        // 2026-10-08 实验：杰理固件对 APP&SHUT 的应答是先 MCU&WIFIC 再 MCU&SHUT，
        // 若 MCU&WIFIC 晚于 APP&WIFIO 到达会吞掉 isWifiAccelerationUserInitiated
        // 导致 WIFIS&2 轮询空转（真机偶发）。协议连发的指令间隔从 100ms 加到
        // 200ms，拉开与 SHUT 先导应答的时序，观察竞态窗口是否消除。
        // ⚠️ 实验参数：验证通过后若要恢复节奏，改回 0.1 / 0.2 并保留观察日志。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.protocolClient getWifiInfo];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openWifi];
        });
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)connectSocket {
    [self.replyParser connectSocket];
}

#pragma mark - 设置管理

- (void)getSupportSettings {
    if (self.protocolClient) {
        [self.protocolClient getSupportSettings];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)getSettingStatus {
    if (self.protocolClient) {
        [self.protocolClient getSettingStatus];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)setSetting:(NSString *)key value:(NSString *)value {
    if (self.protocolClient) {
        self.replyParser.currentSettingName = key;
        [self.protocolClient setSetting:key value:value];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

#pragma mark - 其他

- (void)formatDisk {
    if (self.protocolClient) {
        [self.protocolClient formatDisk];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)bindDevice:(NSString *)secret {
    if (self.protocolClient) {
        [self.protocolClient bindDevice:secret];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)unbindDevice {
    if (self.protocolClient) {
        [self.protocolClient unbindDevice];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

#pragma mark - OTA

- (void)startOTA:(long)fileSize {
    if (self.protocolClient) {
        [self.protocolClient startOTA:fileSize];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)startOTA:(long)fileSize crc32:(NSString *)crc32 {
    if (self.protocolClient) {
        [self.protocolClient startOTA:fileSize crc32:crc32];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)sendOTAData:(NSData *)data {
    if (self.protocolClient) {
        [self.protocolClient sendOTAData:data];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)sendOTADataEnd {
    if (self.protocolClient) {
        [self.protocolClient sendOTADataEnd];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

- (void)stopOTA {
    // 用户主动取消：保存原 otaDelegate，临时装上 self 拦截 MCU&OT&ERR 派发，
    // 设备回执 ERR 后统一派发 onOtaErrorWithCode:JWDOtaErrorCancelledByUser
    // （错误码模型：主动取消也走错误回调，用专属码区分来源），派发完毕恢复。
    self.otaUserCancelled = YES;
    self.otaDelegateBeforeCancel = self.otaDelegate;
    self.replyParser.otaDelegate = self;
    if (self.protocolClient) {
        [self.protocolClient stopOTA];
    } else {
        [JWDSdkLogger e:TAG msg:@"蓝牙未连接"];
    }
}

#pragma mark - JWDOtaDelegate（中间拦截层：主动取消错误码改写）

/**
 * 中间拦截：MCU&OT&ERR 到达时由 replyParser 直接调用本方法。
 * 按 otaUserCancelled 标志改写错误码后统一派发唯一错误出口：
 *   - 标志 YES（stopOTA 后设备回 ERR）→ onOtaErrorWithCode:JWDOtaErrorCancelledByUser
 *   - 标志 NO（设备真正的错误）→ onOtaErrorWithCode:{设备码}
 * 处理后恢复原 otaDelegate 并清标志。
 */
- (void)onOtaErrorWithCode:(JWDOtaErrorCode)code {
    BOOL wasUserCancel = self.otaUserCancelled;
    self.otaUserCancelled = NO;  // 一次性标志，最迟在这里复位
    id<JWDOtaDelegate> original = self.otaDelegateBeforeCancel ?: self.otaDelegate;
    // 立即恢复原 otaDelegate（避免后续 OTA 错误走错路径）
    self.replyParser.otaDelegate = original;
    self.otaDelegateBeforeCancel = nil;

    if (!original || original == (id)self) { return; }

    JWDOtaErrorCode finalCode = wasUserCancel ? JWDOtaErrorCancelledByUser : code;
    if ([original respondsToSelector:@selector(onOtaErrorWithCode:)]) {
        [original onOtaErrorWithCode:finalCode];
    }
}

#pragma mark - 释放

- (void)releaseSDK {
    [self disConnect];
    [self.replyParser releaseResources];
    [JWDSdkLogger i:TAG msg:@"SDK资源已释放"];
}

@end
