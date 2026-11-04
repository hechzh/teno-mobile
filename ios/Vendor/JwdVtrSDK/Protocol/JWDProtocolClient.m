//
//  JWDProtocolClient.m
//  JwdVtrSDK
//

#import "JWDProtocolClient.h"
#import "JWDSdkLogger.h"
#import "JWDTool.h"

static NSString *const TAG = @"JWDProtocolClient";

@interface JWDProtocolClient ()
@property (nonatomic, weak) CBPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *writeCharact;
@end

@implementation JWDProtocolClient

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral
                      writeCharact:(CBCharacteristic *)writeCharact {
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        _writeCharact = writeCharact;
    }
    return self;
}

#pragma mark - 命令编码与发送

- (void)sendCommand:(NSString *)command {
    [JWDSdkLogger logProtocolSend:TAG protocol:command];
    NSData *bytes = [self encodeCommand:command];
    [self sendRawData:bytes];
}

- (NSData *)encodeCommand:(NSString *)command {
    NSString *ascii = [JWDTool stringToAscii:command];
    NSString *hex = [JWDTool asciiToHex:ascii];
    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"编码命令 - ASCII: %@, Hex: %@", ascii, hex]];
    return [JWDTool hexStringToData:hex];
}

- (void)sendRawData:(NSData *)data {
    if (!self.peripheral || !self.writeCharact) {
        [JWDSdkLogger e:TAG msg:@"设备未连接，无法发送消息"];
        return;
    }
    [self.peripheral writeValue:data
              forCharacteristic:self.writeCharact
                           type:CBCharacteristicWriteWithoutResponse];
}

#pragma mark - 录音控制

- (void)startRecord      { [self sendCommand:@"APP&STA"]; }
- (void)stopRecord       { [self sendCommand:@"APP&STO"]; }
- (void)pauseRecord      { [self sendCommand:@"APP&PAU"]; }
- (void)resumeRecord     { [self sendCommand:@"APP&RESU"]; }
- (void)getRecordStatus  { [self sendCommand:@"APP&STE"]; }
- (void)getRecordMode    { [self sendCommand:@"APP&REC&SECEN"]; }
- (void)getRecordInfo    { [self sendCommand:@"APP&RT"]; }

#pragma mark - 文件管理

- (void)getFileDirs      { [self sendCommand:@"APP&LIST_DIRS"]; }

- (void)getDirFiles:(NSString *)dir {
    [self sendCommand:[NSString stringWithFormat:@"APP&LIST&%@", dir]];
}

- (void)importFile:(NSString *)dir fileName:(NSString *)fileName {
    [self sendCommand:[NSString stringWithFormat:@"APP&U&%@&%@", dir, fileName]];
}

- (void)resumeFile:(NSString *)dir filename:(NSString *)filename breakTime:(long)breakTime {
    [self sendCommand:[NSString stringWithFormat:@"APP&C&%@&%@&%ld", dir, filename, breakTime]];
}

- (void)cancelImport     { [self sendCommand:@"APP&SHUT"]; }
- (void)stopFileTransfer { [self sendCommand:@"APP&SHUT"]; }

- (void)deleteFile:(NSString *)dir fileName:(NSString *)fileName {
    [self sendCommand:[NSString stringWithFormat:@"APP&D&%@&%@", dir, fileName]];
}

- (void)getFileBk:(NSString *)dir fileName:(NSString *)fileName {
    // 注意: dir 与 fileName 之间使用 "/" 分隔（2026-09-15 协议变更，旧版为 "&"）
    [self sendCommand:[NSString stringWithFormat:@"APP&BK&%@/%@", dir, fileName]];
}

#pragma mark - 设备信息

- (void)getBattery       { [self sendCommand:@"APP&BAT"]; }
- (void)getCapacity      { [self sendCommand:@"APP&SPACE"]; }
- (void)getFwVersion     { [self sendCommand:@"APP&FW"]; }
- (void)getWifiVersion   { [self sendCommand:@"APP&WF"]; }
- (void)getDeviceMac     { [self sendCommand:@"APP&MAC"]; }
- (void)getDeviceTime    { [self sendCommand:@"APP&GT"]; }
- (void)setUsbTransferState:(int)state {
    // 杰理方案 V1.1：APP&USB&STA，STA: 1=开启, 0=关闭
    [self sendCommand:[NSString stringWithFormat:@"APP&USB&%d", state]];
}

- (void)syncTime {
    NSString *timeData = [JWDTool currentTimeString];
    [self sendCommand:[NSString stringWithFormat:@"APP&T&%@", timeData]];
}

#pragma mark - WiFi

- (void)openWifi         { [self sendCommand:@"APP&WIFIO"]; }
- (void)closeWifi        { [self sendCommand:@"APP&WIFIC"]; }
- (void)getWifiInfo      { [self sendCommand:@"APP&WIFI"]; }
- (void)getWifiStatus    { [self sendCommand:@"APP&WIFIS"]; }
- (void)switchSocketSend { [self sendCommand:@"APP&U&WIFI"]; }

#pragma mark - 设置

- (void)getSupportSettings { [self sendCommand:@"APP&FUNCTION"]; }
- (void)getSettingStatus   { [self sendCommand:@"APP&SET"]; }

- (void)setSetting:(NSString *)key value:(NSString *)value {
    [self sendCommand:[NSString stringWithFormat:@"APP&%@&%@", key, value]];
}

#pragma mark - 其他

- (void)formatDisk  { [self sendCommand:@"APP&BLE&RESET"]; }

- (void)bindDevice:(NSString *)secret {
    [self sendCommand:[NSString stringWithFormat:@"APP&SK&%@", secret]];
}

- (void)unbindDevice { [self sendCommand:@"APP&BLE&OFF"]; }

#pragma mark - OTA

- (void)startOTA:(long)len {
    [self sendCommand:[NSString stringWithFormat:@"APP&OTA&%ld", len]];
}

- (void)startOTA:(long)len crc32:(NSString *)crc32 {
    // 杰理方案：APP&OTA&{len}&{crc32}，设备校验固件包大小与完整性前置条件
    if (crc32.length > 0) {
        [self sendCommand:[NSString stringWithFormat:@"APP&OTA&%ld&%@", len, crc32]];
    } else {
        [self sendCommand:[NSString stringWithFormat:@"APP&OTA&%ld", len]];
    }
}

- (void)sendOTAData:(NSData *)data {
    [self sendRawData:data];
}

- (void)sendOTADataEnd { [self sendCommand:@"APP&OT&OVER"]; }

- (void)stopOTA { [self sendCommand:@"APP&OT&SHUT"]; }

@end
