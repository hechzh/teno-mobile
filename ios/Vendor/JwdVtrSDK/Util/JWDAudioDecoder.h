//
//  JWDAudioDecoder.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 音频流解码器抽象协议
//
//  为什么需要这个协议？
//  - 录音流可能来自不同型号的设备：
//      · 老型号 / VTR 系列：MP3 裸流 → JWDMp3Decoder
//      · 新型号 / 带 "_P" 前缀的设备：Opus 裸流 → JWDOpusDecoder
//  - JWDReplyParser 内部需要根据设备型号动态选择解码器，但不希望硬依赖具体类。
//  - 用协议隔离后，未来新增格式（AAC / SBC）只需新增实现类，
//    无需修改 ReplyParser 主流程。
//
//  使用：
//      id<JWDAudioDecoder> decoder = [self makeDecoderForName:deviceName];
//      decoder.pcmDataBlock = ^(NSData *pcm, int sr, int ch) { ... };
//      [decoder start];
//      [decoder decodeData:incomingFrame];
//      [decoder stop];
//
//  SDK 内部使用，暂不对外暴露。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 音频解码器类型枚举（按设备型号自动判定）
 */
typedef NS_ENUM(NSInteger, JWDAudioDecoderType) {
    /** MP3 裸流 → JWDMp3Decoder（默认，老型号 / VTR） */
    JWDAudioDecoderTypeMP3 = 0,
    /** Opus 裸流 → JWDOpusDecoder（新型号，设备名含 _P 前缀） */
    JWDAudioDecoderTypeOpus = 1,
};

/**
 * PCM 数据回调（解码成功后触发）
 * @param pcmData       解码后的 PCM 数据（16-bit Little-Endian）
 * @param sampleRate    采样率（默认 16000Hz）
 * @param channelCount  声道数（默认 1=单声道）
 */
typedef void(^JWDPcmDataBlock)(NSData *pcmData, int sampleRate, int channelCount);


/**
 * 音频流解码器抽象协议
 *
 * 任何"接收压缩裸流、按帧自动切割、回调 PCM" 的解码器都应实现该协议。
 * 协议方法签名对齐原 JWDMp3Decoder，便于现有调用代码零成本切换。
 */
@protocol JWDAudioDecoder <NSObject>

/** PCM 数据回调（解码成功后触发） */
@property (nonatomic, copy, nullable) JWDPcmDataBlock pcmDataBlock;

/** 解码器是否正在运行 */
@property (nonatomic, assign, readonly) BOOL isRunning;

/** 启动解码器（创建底层 AudioConverter / libopus decoder 等） */
- (BOOL)start;

/** 解码数据（接收裸流，内部自动切帧 + 解码） */
- (void)decodeData:(NSData *)data;

/** 停止解码器并释放资源 */
- (void)stop;

@end


/**
 * 根据设备蓝牙名称判定音频解码类型。
 *
 * 判定规则（与 Android 端对齐）：
 *      设备名包含 "_P"（下划线 + 大写 P，型号前缀，如 "VTR7900_P1234567890"）
 *          → 使用 Opus 解码（新型号录音流）
 *      其他
 *          → 使用 MP3 解码（兼容老型号）
 *
 * @param deviceName 蓝牙外设名（CBPeripheral.name），可为 nil/空
 * @return 解码类型
 */
FOUNDATION_EXPORT JWDAudioDecoderType JWDAudioDecoderTypeForDeviceName(NSString * _Nullable deviceName);

NS_ASSUME_NONNULL_END
