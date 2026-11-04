//
//  JWDMp3Decoder.m
//  JwdVtrSDK
//
//  MP3 流式解码器实现（流对齐 JWDOpusDecoder 状态机设计）
//
//  数据契约（VTR 录音笔，2026-09-28 用户实测口径）：
//      - 16 kHz / 16-bit / 单声道
//      - MPEG 2 Layer III，32 kbps CBR，无 CRC
//      - 帧头两个字节固定 0xFF 0xF3
//      - 帧长固定 144 字节（72 × 32000 / 16000 = 144，32kbps@16kHz 恰好整除，
//        padding 位恒为 0，无变长帧）
//      - 每帧 576 samples（MPEG 2 Layer III；非 MPEG1 的 1152）
//
//  拆帧状态机（对齐 JWDOpusDecoder）：
//      SYNCED（已同步）：帧头 == 0xFF 0xF3 → 整帧解码，前进 144 字节；
//                       帧头不符 → 进入 RESYNC
//      RESYNC（重同步）：向后扫描 0xFF 0xF3（唯一可信同步锚点），
//                       找到 → 从该位置恢复同步，其间字节按丢帧处理；
//                       找不到 → 全部丢弃，保留尾部 1 字节（防 0xFF 在包尾
//                       与下一包首字节组成锚点）
//
//  MP3 无 PLC（丢帧隐蔽）机制：重同步丢弃的字节直接损失对应时长，
//  回放表现为时间轴缩短，属于协议设计内的预期行为。
//

#import "JWDMp3Decoder.h"
#import <AudioToolbox/AudioToolbox.h>
#import "JWDSdkLogger.h"

static NSString *const TAG = @"JWDMp3Decoder";

// === VTR 录音笔 MP3 流固定参数（2026-09-28 确认） ===
static const UInt8 MP3_SYNC_BYTE_0 = 0xFF;  // 帧同步第一字节
static const UInt8 MP3_SYNC_BYTE_1 = 0xF3;  // 帧同步第二字节：MPEG2 + LayerIII + 无CRC
static const NSUInteger MP3_FRAME_BYTES = 144; // 72*32000/16000，CBR 固定帧长（无 padding）

// PCM 输出缓冲区大小（足够容纳一帧解码后的 PCM）
// MPEG2 L3 每帧 576 samples × 2 字节 = 1152 字节；取整为 2 的幂便于分配
static const UInt32 PCM_OUTPUT_BUFFER_SIZE = 4096;

// Apple 编解码器厂商标识
// iOS：kAppleSoftwareAudioCodecManufacturer / kAppleHardwareAudioCodecManufacturer
// 已在系统头文件 AudioFormat.h 中定义（TARGET_OS_IPHONE 块内）。
// macOS（测试台编译）：这些常量被平台裁剪不可见，用相同值的字面量 fallback
// （'appl' / 'aphw'，与 iOS 头文件定义完全一致，无行为差异）。
#if TARGET_OS_IPHONE && !defined(JWD_MP3_TESTBENCH)
#define JWD_CODEC_MFR_SOFTWARE kAppleSoftwareAudioCodecManufacturer
#define JWD_CODEC_MFR_HARDWARE kAppleHardwareAudioCodecManufacturer
#else
#define JWD_CODEC_MFR_SOFTWARE ((uint32_t)'appl')
#define JWD_CODEC_MFR_HARDWARE ((uint32_t)'aphw')
#endif

// AudioConverter 输入回调上下文
typedef struct {
    const UInt8 *mp3Data;
    UInt32 mp3DataSize;
    UInt32 offset;
    AudioStreamPacketDescription packetDesc;
} JWDInputContext;

// AudioConverter 输入数据回调（C 函数）
static OSStatus mp3InputCallback(AudioConverterRef inAudioConverter,
                                  UInt32 *ioNumberDataPackets,
                                  AudioBufferList *ioData,
                                  AudioStreamPacketDescription **outDataPacketDescription,
                                  void *inUserData) {
    JWDInputContext *ctx = (JWDInputContext *)inUserData;
    UInt32 remaining = ctx->mp3DataSize - ctx->offset;

    if (remaining == 0) {
        *ioNumberDataPackets = 0;
        return -1; // 非零返回值表示输入暂时耗尽，AudioConverter 会输出已解码的数据
    }

    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mData = (void *)(ctx->mp3Data + ctx->offset);
    ioData->mBuffers[0].mDataByteSize = remaining;
    ioData->mBuffers[0].mNumberChannels = 1;

    // 对于 MP3 等压缩格式，必须提供 AudioStreamPacketDescription
    ctx->packetDesc.mStartOffset = 0;
    ctx->packetDesc.mDataByteSize = remaining;
    ctx->packetDesc.mVariableFramesInPacket = 0;
    if (outDataPacketDescription) {
        *outDataPacketDescription = &ctx->packetDesc;
    }

    *ioNumberDataPackets = 1;
    ctx->offset = ctx->mp3DataSize; // 标记所有数据已提供

    return noErr;
}

@interface JWDMp3Decoder () {
    AudioConverterRef _converter;
    AudioStreamBasicDescription _mp3Format;
    AudioStreamBasicDescription _pcmFormat;
    UInt8 *_pcmBuffer;

    // MP3 帧缓冲区（用于帧切割）
    NSMutableData *_streamBuffer;

    // 拆帧统计（stop 时输出，用于诊断链路质量）
    NSUInteger _totalFrameCount;   // 累计切片帧数（每 144 字节计一帧）
    NSUInteger _invalidFrameCount; // 帧头 != 0xFF 0xF3 的帧数
    NSUInteger _resyncCount;       // 重同步发生次数
    NSUInteger _droppedBytes;      // 重同步丢弃的字节总数
}
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channelCount;
@end

@implementation JWDMp3Decoder

- (instancetype)initWithSampleRate:(int)sampleRate channelCount:(int)channelCount {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        _channelCount = channelCount;
        _streamBuffer = [NSMutableData dataWithCapacity:MP3_FRAME_BYTES * 8];
    }
    return self;
}

- (instancetype)init {
    return [self initWithSampleRate:16000 channelCount:1];
}

- (void)dealloc {
    [self stop];
}

#pragma mark - 生命周期

- (BOOL)start {
    if (self.isRunning) return YES;

    // 配置 MP3 输入格式（MPEG 2 Layer III / 16 kHz / 单声道 / 32 kbps）
    memset(&_mp3Format, 0, sizeof(_mp3Format));
    _mp3Format.mFormatID = kAudioFormatMPEGLayer3;
    _mp3Format.mSampleRate = self.sampleRate;
    _mp3Format.mChannelsPerFrame = self.channelCount;

    // 配置 PCM 输出格式（16-bit Signed Integer, Little-Endian）
    memset(&_pcmFormat, 0, sizeof(_pcmFormat));
    _pcmFormat.mFormatID = kAudioFormatLinearPCM;
    _pcmFormat.mSampleRate = self.sampleRate;
    _pcmFormat.mChannelsPerFrame = self.channelCount;
    _pcmFormat.mBitsPerChannel = 16;
    _pcmFormat.mBytesPerFrame = 2 * self.channelCount;
    _pcmFormat.mFramesPerPacket = 1;
    _pcmFormat.mBytesPerPacket = _pcmFormat.mBytesPerFrame;
    _pcmFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;

    // 查找可用的 MP3 解码器，优先使用软件解码器（避免 out-of-process 渲染）
    AudioClassDescription *decoder = [self findAudioDecoderWithFormatID:kAudioFormatMPEGLayer3
                                                          manufacturer:JWD_CODEC_MFR_SOFTWARE];
    OSStatus status;
    if (decoder) {
        [JWDSdkLogger d:TAG msg:@"使用软件解码器创建 AudioConverter"];
        status = AudioConverterNewSpecific(&_mp3Format, &_pcmFormat, 1, decoder, &_converter);
    } else {
        // 回退到硬件解码器
        decoder = [self findAudioDecoderWithFormatID:kAudioFormatMPEGLayer3
                                      manufacturer:JWD_CODEC_MFR_HARDWARE];
        if (decoder) {
            [JWDSdkLogger d:TAG msg:@"使用硬件解码器创建 AudioConverter"];
            status = AudioConverterNewSpecific(&_mp3Format, &_pcmFormat, 1, decoder, &_converter);
        } else {
            // 最终回退到默认方式
            [JWDSdkLogger w:TAG msg:@"未找到指定的 MP3 解码器，使用默认 AudioConverterNew"];
            status = AudioConverterNew(&_mp3Format, &_pcmFormat, &_converter);
        }
    }

    if (status != noErr) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:
            @"AudioConverter 创建失败 (OSStatus: %d)", (int)status]];
        return NO;
    }

    // 分配 PCM 输出缓冲区
    _pcmBuffer = (UInt8 *)malloc(PCM_OUTPUT_BUFFER_SIZE);
    [_streamBuffer setLength:0];

    _totalFrameCount = 0;
    _invalidFrameCount = 0;
    _resyncCount = 0;
    _droppedBytes = 0;

    self.isRunning = YES;
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
        @"MP3 解码器启动 (sampleRate=%d, channels=%d, frameBytes=%lu, sync=%02X %02X)",
        self.sampleRate, self.channelCount,
        (unsigned long)MP3_FRAME_BYTES, MP3_SYNC_BYTE_0, MP3_SYNC_BYTE_1]];
    return YES;
}

- (void)stop {
    if (!self.isRunning) {
        // 防御：即便没 start，也确保释放解码器与缓冲
        if (_converter) {
            AudioConverterDispose(_converter);
            _converter = NULL;
        }
        if (_pcmBuffer) {
            free(_pcmBuffer);
            _pcmBuffer = NULL;
        }
        return;
    }

    self.isRunning = NO;

    if (_converter) {
        AudioConverterDispose(_converter);
        _converter = NULL;
    }

    if (_pcmBuffer) {
        free(_pcmBuffer);
        _pcmBuffer = NULL;
    }

    [_streamBuffer setLength:0];
    // 打印本次录音的切帧统计（总帧数 / 帧头异常帧 / 重同步 / 丢弃字节）
    double invalidRatio = (_totalFrameCount > 0)
        ? (double)_invalidFrameCount * 100.0 / (double)_totalFrameCount
        : 0.0;
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
        @"MP3 解码统计: 总 %lu 帧, 帧头异常 %lu 帧 (%.2f%%), 重同步 %lu 次, 丢弃 %lu 字节",
        (unsigned long)_totalFrameCount,
        (unsigned long)_invalidFrameCount,
        invalidRatio,
        (unsigned long)_resyncCount,
        (unsigned long)_droppedBytes]];
    [JWDSdkLogger i:TAG msg:@"MP3 解码器已停止"];
}

#pragma mark - 解码器查找

/**
 * 查找指定格式的音频解码器
 * @param formatID    音频格式 ID（如 kAudioFormatMPEGLayer3）
 * @param manufacturer 解码器厂商（软件或硬件）
 * @return AudioClassDescription 指针（静态变量，无需调用者释放），找不到返回 NULL
 */
- (AudioClassDescription *)findAudioDecoderWithFormatID:(AudioFormatID)formatID
                                          manufacturer:(uint32_t)manufacturer {
    static AudioClassDescription desc;
    UInt32 decoderSpecific = formatID;
    UInt32 size = 0;

    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders,
                                                 sizeof(decoderSpecific),
                                                 &decoderSpecific,
                                                 &size);
    if (status != noErr || size == 0) {
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
            @"AudioFormatGetPropertyInfo 失败 (OSStatus: %d)", (int)status]];
        return NULL;
    }

    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];

    status = AudioFormatGetProperty(kAudioFormatProperty_Decoders,
                                    sizeof(decoderSpecific),
                                    &decoderSpecific,
                                    &size,
                                    descriptions);
    if (status != noErr) {
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
            @"AudioFormatGetProperty 失败 (OSStatus: %d)", (int)status]];
        return NULL;
    }

    for (unsigned int i = 0; i < count; i++) {
        if (formatID == descriptions[i].mSubType && manufacturer == descriptions[i].mManufacturer) {
            desc = descriptions[i];
            return &desc;
        }
    }
    return NULL;
}

#pragma mark - 解码

- (void)decodeData:(NSData *)mp3Data {
    if (!self.isRunning || !_converter || mp3Data.length == 0) return;

    // 追加到缓冲区
    [_streamBuffer appendData:mp3Data];

    // 拆帧主循环（带重同步）
    NSUInteger consumed = [self drainStreamBuffer];
    if (consumed > 0) {
        if (consumed < _streamBuffer.length) {
            [_streamBuffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
        } else {
            [_streamBuffer setLength:0];
        }
    }
}

/**
 * 拆帧主循环（带重同步）。
 *
 * 状态机：
 *   SYNCED（已同步）：帧头 == 0xFF 0xF3 → 整帧解码，前进 144 字节；
 *                    帧头 != 0xFF 0xF3 → 丢弃该帧头位置，进入 RESYNC
 *   RESYNC（重同步）：向后扫描 0xFF 0xF3（唯一可信同步锚点），
 *                    找到 → 从该位置恢复同步（其间数据按丢帧处理）
 *                    找不到 → 全部丢弃，保留尾部 1 字节（防 0xFF 在包尾
 *                            与下一包首字节组成锚点，等下一包拼接判断）
 *
 * @return 本次消费掉的字节数（调用方据此修剪缓冲）
 */
- (NSUInteger)drainStreamBuffer {
    const UInt8 *bytes = (const UInt8 *)_streamBuffer.bytes;
    NSUInteger length = _streamBuffer.length;
    NSUInteger offset = 0;
    BOOL resyncing = NO;   // 当前是否处于重同步扫描状态

    while (length - offset >= MP3_FRAME_BYTES) {
        const UInt8 *frame = bytes + offset;

        if (!resyncing) {
            // ---- 同步态：帧头判定 ----
            _totalFrameCount++;
            if (frame[0] == MP3_SYNC_BYTE_0 && frame[1] == MP3_SYNC_BYTE_1) {
                [self decodeSingleFrame:frame size:(UInt32)MP3_FRAME_BYTES];
                offset += MP3_FRAME_BYTES;
                continue;
            }
            // 帧头 != 0xFF 0xF3 → 帧头不对，丢弃该帧，进入重同步找下个帧头
            _invalidFrameCount++;
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                @"MP3 帧头异常 (offset=%lu): %02X %02X ..., 进入重同步",
                (unsigned long)offset, frame[0], frame[1]]];
            resyncing = YES;
            // 不 continue，直接落入重同步扫描（从当前 offset 开始找同步点）
        }

        // ---- 重同步态：向后找 0xFF 0xF3 ----
        NSUInteger sync = [self findSyncAnchor:bytes from:offset to:length];
        if (sync == NSNotFound) {
            // 本包内无同步点：丢弃（保留最后 1 字节防 0xFF 在包尾）
            NSUInteger drop = (length - offset > 1) ? (length - offset - 1) : 0;
            if (drop > 0) {
                _droppedBytes += drop;
                _resyncCount++;
                offset += drop;
            }
            break;
        }
        // 找到同步点：丢弃 [offset, sync) 的脏数据
        NSUInteger drop = sync - offset;
        if (drop > 0) {
            _droppedBytes += drop;
            _resyncCount++;
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                @"MP3 重同步: 丢弃 %lu 字节脏数据，同步点 offset=%lu",
                (unsigned long)drop, (unsigned long)sync]];
        }
        offset = sync;
        resyncing = NO;
    }

    // 尾部不足一帧的字节保留到下一包（缓冲修剪由调用方做）
    return offset;
}

/**
 * 在 [from, to) 范围内查找同步锚点 0xFF 0xF3 的位置。
 * @return 找到的索引；找不到返回 NSNotFound
 */
- (NSUInteger)findSyncAnchor:(const UInt8 *)bytes from:(NSUInteger)from to:(NSUInteger)to {
    if (to < from + 2) return NSNotFound;
    NSUInteger last = to - 2;   // 最后一个可能的起始位置
    for (NSUInteger i = from; i <= last; i++) {
        if (bytes[i] == MP3_SYNC_BYTE_0 && bytes[i + 1] == MP3_SYNC_BYTE_1) {
            return i;
        }
    }
    return NSNotFound;
}

- (void)decodeSingleFrame:(const UInt8 *)frameData size:(UInt32)frameSize {
    // 设置输入上下文
    JWDInputContext inputCtx;
    inputCtx.mp3Data = frameData;
    inputCtx.mp3DataSize = frameSize;
    inputCtx.offset = 0;

    // 设置输出缓冲区
    AudioBufferList outputBufferList;
    outputBufferList.mNumberBuffers = 1;
    outputBufferList.mBuffers[0].mNumberChannels = self.channelCount;
    outputBufferList.mBuffers[0].mDataByteSize = PCM_OUTPUT_BUFFER_SIZE;
    outputBufferList.mBuffers[0].mData = _pcmBuffer;

    // 输出 packet 数：MPEG 2 Layer III 每帧 576 samples（16kHz → 36ms）
    UInt32 outputPacketCount = 576;

    // 对于压缩格式输入，提供输出 packet description
    AudioStreamPacketDescription outputPacketDesc;

    OSStatus status = AudioConverterFillComplexBuffer(_converter,
                                                       mp3InputCallback,
                                                       &inputCtx,
                                                       &outputPacketCount,
                                                       &outputBufferList,
                                                       &outputPacketDesc);

    // 即使输入回调返回非零错误码（输入耗尽），输出缓冲区中可能仍有已解码的 PCM 数据
    if (outputPacketCount > 0 && outputBufferList.mBuffers[0].mDataByteSize > 0) {
        NSData *pcmData = [NSData dataWithBytes:_pcmBuffer
                                         length:outputBufferList.mBuffers[0].mDataByteSize];
        if (self.pcmDataBlock) {
            self.pcmDataBlock(pcmData, self.sampleRate, self.channelCount);
        }
    } else if (status != noErr && status != -1) {
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
            @"MP3 解码失败 (OSStatus: %d, frameSize: %u)", (int)status, (unsigned)frameSize]];
    }
}

@end
