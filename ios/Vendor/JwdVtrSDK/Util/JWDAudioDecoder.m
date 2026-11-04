//
//  JWDAudioDecoder.m
//  JwdVtrSDK
//
//  当前仅承载 JWDAudioDecoderTypeForDeviceName 工厂函数。
//  具体实现类（JWDOpusDecoder / JWDMp3Decoder）独立编译为各自 .m。
//

#import "JWDAudioDecoder.h"

JWDAudioDecoderType JWDAudioDecoderTypeForDeviceName(NSString *deviceName) {
    if (deviceName.length == 0) {
        return JWDAudioDecoderTypeMP3;
    }
    // 设备名包含 "_P" → 新型号 Opus 流（与 Android 端判定规则一致）
    if ([deviceName rangeOfString:@"_P"].location != NSNotFound) {
        return JWDAudioDecoderTypeOpus;
    }
    return JWDAudioDecoderTypeMP3;
}
