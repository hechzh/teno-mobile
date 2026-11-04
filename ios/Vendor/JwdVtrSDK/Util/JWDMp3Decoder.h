//
//  JWDMp3Decoder.h
//  JwdVtrSDK
//
//  JWD VTR SDK - MP3 裸流解码器（MP3 → PCM）
//  对齐 Android 端 Mp3Decoder（MediaCodec 实现）
//

#import <Foundation/Foundation.h>
#import "JWDAudioDecoder.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * MP3 解码器
 *
 * 使用 AudioToolbox AudioConverter 将设备实时传输的 MP3 裸流解码为 PCM 数据。
 * 对齐 Android 端 Mp3Decoder 的行为：
 * - 接收 MP3 裸流数据（任意长度的数据块）
 * - 自动进行帧切割与解码
 * - 通过回调输出 PCM 数据
 *
 * 使用流程:
 * 1. 创建实例并设置 pcmDataBlock
 * 2. 调用 start 启动解码器
 * 3. 调用 decodeData: 传入 MP3 数据
 * 4. 通过 pcmDataBlock 接收 PCM 数据
 * 5. 调用 stop 停止解码器
 */
@interface JWDMp3Decoder : NSObject <JWDAudioDecoder>

/** PCM 数据回调（解码成功后触发） */
@property (nonatomic, copy, nullable) JWDPcmDataBlock pcmDataBlock;

/** 解码器是否正在运行 */
@property (nonatomic, assign, readonly) BOOL isRunning;

/**
 * 初始化 MP3 解码器
 * @param sampleRate   采样率（默认 16000）
 * @param channelCount 声道数（1=单声道, 2=立体声）
 */
- (instancetype)initWithSampleRate:(int)sampleRate channelCount:(int)channelCount;

/** 启动解码器 */
- (BOOL)start;

/** 解码 MP3 数据（接收裸流，内部自动帧切割 + 解码） */
- (void)decodeData:(NSData *)mp3Data;

/** 停止解码器并释放资源 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
