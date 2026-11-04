//
//  JWDOpusDecoder.h
//  JwdVtrSDK
//
//  JWD VTR SDK - Opus 裸流解码器（Opus → PCM）
//  对齐 Android 端 OpusDecoder（MediaCodec 实现）
//
//  数据格式（VTR 录音笔，16 kHz / 16-bit / 单声道 / 32 kbps）：
//      [Opus packet, 固定 80 字节] × N（无分隔符，连续拼接）
//  每个 packet 开头两个字节 0x4B 0x41 是 RFC 6716 §3.1 定义的 TOC，
//  不是厂商魔数，库会自动识别。32 kbps CBR ⇒ 80 B × 8 / 0.02 = 32000 bps
//
//  与 JWDMp3Decoder 接口对齐：init → start → decodeData: → stop
//  两者通过 JWDReplyParser 内部的音频解码协议路由，
//  上层 App 无需关心当前是 MP3 还是 Opus 流。
//

#import <Foundation/Foundation.h>
#import "JWDAudioDecoder.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Opus 解码器
 *
 * 使用 libopus (opus_decoder_create / opus_decode) 将设备实时传输的 Opus 裸流
 * 解码为 16-bit Little-Endian PCM。对齐 Android 端 OpusDecoder 行为：
 * - 接收 Opus 裸流数据（任意长度的数据块）
 * - 内部按固定 80 字节切帧、调 opus_decode
 * - 失败帧通过 opus_decode(NULL, 0, ...) 生成 PLC 帧保持时间轴连续
 * - 通过 pcmDataBlock 回调输出 PCM
 *
 * 使用流程:
 * 1. 创建实例并设置 pcmDataBlock
 * 2. 调用 start 启动解码器（创建 libopus decoder）
 * 3. 调用 decodeData: 传入 Opus 数据
 * 4. 通过 pcmDataBlock 接收 PCM 数据（16-bit / 16 kHz / 单声道）
 * 5. 调用 stop 停止解码器并销毁 libopus decoder
 */
@interface JWDOpusDecoder : NSObject <JWDAudioDecoder>

/** PCM 数据回调（解码成功后触发） */
@property (nonatomic, copy, nullable) JWDPcmDataBlock pcmDataBlock;

/** 解码器是否正在运行 */
@property (nonatomic, assign, readonly) BOOL isRunning;

/**
 * 初始化 Opus 解码器
 * @param sampleRate   采样率（默认 16000，对齐 VTR 录音笔规格）
 * @param channelCount 声道数（1=单声道, 2=立体声；当前仅 1 已验证）
 */
- (instancetype)initWithSampleRate:(int)sampleRate channelCount:(int)channelCount;

/** 启动解码器 */
- (BOOL)start;

/** 解码 Opus 数据（接收裸流，内部自动按 80 字节切帧 + 解码） */
- (void)decodeData:(NSData *)opusData;

/** 停止解码器并释放资源 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
