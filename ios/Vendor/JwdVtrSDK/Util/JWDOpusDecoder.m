//
//  JWDOpusDecoder.m
//  JwdVtrSDK
//
//  Opus 流式解码器实现（流对齐 JWDMp3Decoder）
//
//  数据契约（与 OpusDecodeDemo 中 JwdOpusDecoder 完全相同）：
//      - 16 kHz, 16-bit signed little-endian PCM, 单声道
//      - Opus 帧大小：80 字节（VTR 录音笔写死）
//      - 每帧开头两个字节 0x4B 0x41 = Opus TOC（库自动解析）
//      - 32 kbps CBR（80 B × 8 / 0.02 s = 32000 bps）
//
//  libopus 默认给出 20 ms / 帧（16 kHz ⇒ 320 samples/frame）。
//  失败帧通过 opus_decode(NULL, 0, ...) 生成 PLC（packet loss concealment），
//  保持解码后 PCM 时间轴与录音墙钟时间一致，避免播放跳过。
//

#import "JWDOpusDecoder.h"
#import <opus.h>
#import "JWDSdkLogger.h"

static NSString *const TAG = @"JWDOpusDecoder";

// VTR 录音笔 Opus 帧固定 80 字节（20 ms @ 32 kbps CBR）
static const NSUInteger OPUS_FRAME_BYTES = 80;

// PCM 输出缓冲：opus_decode 输出 maxFrameSize samples/channel，
// libopus 规定最大 5760 samples/channel (120 ms @ 48 kHz)。
// 我们实际场景下每帧 ≤ 320 samples/channel × 2 bytes = 640 字节，
// 5760 完全够用，避免按帧重新分配。
static const int OPUS_MAX_FRAME_SAMPLES = 5760;

// === 合法帧头（三种，固件实测归纳）===
//   a) 0x4B 0x41 —— 标准 Opus TOC（主同步锚点）
//   b) 0x4B 0x01 —— TOC 变体
//   c) 0x48      —— 首字节独立判定
// 不符合三种任一的帧视为失步，丢弃到下一个 0x4B 0x41 同步点。
static const UInt8 OPUS_TOC_BYTE_0 = 0x4B;
static const UInt8 OPUS_TOC_BYTE_1 = 0x41;
static const UInt8 OPUS_TOC_ALT_BYTE_1 = 0x01;
static const UInt8 OPUS_HDR_BYTE_48 = 0x48;

// 单次重同步最多插入的 PLC 帧数（防止大段脏数据导致长时间的掩盖音频突刺；
// 80 ms/帧 × 10 = 最多补 2 秒，超过部分直接跳过并记日志）
static const NSUInteger OPUS_PLC_MAX_PER_RESYNC = 10;

/**
 * 帧头合法性判定（80 字节帧的前 1~2 字节）。
 * 命中三种合法模式之一即视为帧边界可信，按整帧解码。
 */
static inline BOOL OpusFrameHeaderIsValid(const UInt8 *frame) {
    if (frame[0] == OPUS_TOC_BYTE_0 &&
        (frame[1] == OPUS_TOC_BYTE_1 || frame[1] == OPUS_TOC_ALT_BYTE_1)) {
        return YES;
    }
    if (frame[0] == OPUS_HDR_BYTE_48) {
        return YES;
    }
    return NO;
}

@interface JWDOpusDecoder () {
    OpusDecoder *_decoder;        // libopus 解码器（C struct，非本类）
    opus_int16 *_pcmBuffer;       // 单帧解码输出缓冲（5760 samples × 2 bytes）
    NSMutableData *_streamBuffer; // 累积字节缓冲，按 80 字节切帧
    NSUInteger _totalFrameCount;   // start → stop 之间累计切片数（每 80 字节计一帧）
    NSUInteger _invalidFrameCount; // 头部不合法但按帧解码的帧数（含 c 类）
    NSUInteger _resyncCount;       // 重同步发生次数
    NSUInteger _droppedBytes;      // 重同步丢弃的字节总数
    NSUInteger _plcFrameCount;     // 重同步期间插入的 PLC 帧总数
    NSUInteger _pendingLossBytes;  // 尚未折算 PLC 的累计丢弃字节（跨 decodeData 调用累积，
                                   // 等重同步成功时一次性折算，避免分块喂入时重复补帧）
}
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channelCount;
@end


@implementation JWDOpusDecoder

#pragma mark - 生命周期

- (instancetype)initWithSampleRate:(int)sampleRate channelCount:(int)channelCount {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        _channelCount = channelCount;
        _streamBuffer = [NSMutableData dataWithCapacity:OPUS_FRAME_BYTES * 8];
    }
    return self;
}

- (instancetype)init {
    return [self initWithSampleRate:16000 channelCount:1];
}

- (void)dealloc {
    [self stop];
}

#pragma mark - 启动 / 停止

- (BOOL)start {
    if (self.isRunning) return YES;

    int err = OPUS_OK;
    _decoder = opus_decoder_create((opus_int32)self.sampleRate,
                                   (int)self.channelCount,
                                   &err);
    if (err != OPUS_OK || _decoder == NULL) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:
            @"opus_decoder_create 失败: %s (sampleRate=%d, channels=%d)",
            opus_strerror(err), self.sampleRate, self.channelCount]];
        _decoder = NULL;
        return NO;
    }

    _pcmBuffer = (opus_int16 *)malloc(sizeof(opus_int16) * OPUS_MAX_FRAME_SAMPLES * self.channelCount);
    if (!_pcmBuffer) {
        [JWDSdkLogger e:TAG msg:@"分配 PCM 缓冲失败"];
        opus_decoder_destroy(_decoder);
        _decoder = NULL;
        return NO;
    }

    [_streamBuffer setLength:0];
    _totalFrameCount = 0;
    _invalidFrameCount = 0;
    _resyncCount = 0;
    _droppedBytes = 0;
    _plcFrameCount = 0;
    _pendingLossBytes = 0;
    self.isRunning = YES;
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
        @"Opus 解码器启动 (sampleRate=%d, channels=%d, frameBytes=%lu)",
        self.sampleRate, self.channelCount, (unsigned long)OPUS_FRAME_BYTES]];
    return YES;
}

- (void)stop {
    if (!self.isRunning) {
        // 防御：即便没 start，也确保释放解码器与缓冲
        if (_decoder) {
            opus_decoder_destroy(_decoder);
            _decoder = NULL;
        }
        if (_pcmBuffer) {
            free(_pcmBuffer);
            _pcmBuffer = NULL;
        }
        return;
    }

    self.isRunning = NO;

    if (_decoder) {
        opus_decoder_destroy(_decoder);
        _decoder = NULL;
    }

    if (_pcmBuffer) {
        free(_pcmBuffer);
        _pcmBuffer = NULL;
    }

    [_streamBuffer setLength:0];
    // 打印本次录音的切帧统计（总帧数 / 头部异常帧 / 重同步 / 丢弃字节 / PLC 帧数）
    double invalidRatio = (_totalFrameCount > 0)
        ? (double)_invalidFrameCount * 100.0 / (double)_totalFrameCount
        : 0.0;
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
        @"Opus 解码统计: 总 %lu 帧, 头部异常 %lu 帧 (%.2f%%), 重同步 %lu 次, 丢弃 %lu 字节, PLC 补帧 %lu",
        (unsigned long)_totalFrameCount,
        (unsigned long)_invalidFrameCount,
        invalidRatio,
        (unsigned long)_resyncCount,
        (unsigned long)_droppedBytes,
        (unsigned long)_plcFrameCount]];
    [JWDSdkLogger i:TAG msg:@"Opus 解码器已停止"];
}

#pragma mark - 解码

- (void)decodeData:(NSData *)opusData {
    if (!self.isRunning || !_decoder || !_pcmBuffer) return;
    if (opusData.length == 0) return;

    [_streamBuffer appendData:opusData];

    NSUInteger consumed = [self drainStreamBuffer];
    if (consumed > 0) {
        if (consumed < _streamBuffer.length) {
            [_streamBuffer replaceBytesInRange:NSMakeRange(0, consumed)
                                    withBytes:NULL
                                       length:0];
        } else {
            [_streamBuffer setLength:0];
        }
    }
}

/**
 * 拆帧主循环（带重同步）。
 *
 * 状态机：
 *   SYNCED（已同步）：帧头合法 → 整帧解码，前进 80 字节；
 *                    帧头不合法 → 丢弃缓冲头 1 字节，进入 RESYNC
 *   RESYNC（重同步）：向后扫描 0x4B 0x41（唯一可信同步锚点，用户规则），
 *                    找到 → 从该位置恢复同步（其间数据按丢帧处理，插 PLC 保持时间轴）
 *                    找不到 → 全部丢弃，保留可能跨包尾部的半个同步点（最后 1 字节）等下一包
 *
 * PLC 补帧上限 OPUS_PLC_MAX_PER_RESYNC：大段脏数据时不无限补静音，
 * 避免录音回放时出现长时间无声段且时间轴被人为拉长。
 *
 * @return 本次消费掉的字节数（调用方据此修剪缓冲）
 */
- (NSUInteger)drainStreamBuffer {
    const UInt8 *bytes = (const UInt8 *)_streamBuffer.bytes;
    NSUInteger length = _streamBuffer.length;
    NSUInteger offset = 0;
    BOOL resyncing = NO;   // 当前是否处于重同步扫描状态

    while (length - offset >= OPUS_FRAME_BYTES) {
        const UInt8 *frame = bytes + offset;

        if (!resyncing) {
            // ---- 同步态：帧头判定 ----
            _totalFrameCount++;
            if (OpusFrameHeaderIsValid(frame)) {
                [self decodeSingleFrame:frame size:OPUS_FRAME_BYTES];
                offset += OPUS_FRAME_BYTES;
                continue;
            }
            // 帧头不合法（说明流错位/污染）→ 进入重同步
            _invalidFrameCount++;
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                @"Opus 帧头异常 (offset=%lu): %02X %02X ..., 进入重同步",
                (unsigned long)offset, frame[0], frame[1]]];
            resyncing = YES;
            // 不 continue，直接落入重同步扫描（从当前 offset 开始找同步点）
        }

        // ---- 重同步态：向后找 0x4B 0x41 ----
        NSUInteger sync = [self findSyncAnchor:bytes from:offset to:length];
        if (sync == NSNotFound) {
            // 本包内无同步点：丢弃（保留最后 1 字节防 0x4B 在包尾）。
            // 丢弃量先累计到 _pendingLossBytes，等重同步成功时统一折算 PLC——
            // 若在此处就补，分块喂入的同一脏段会被每个块各补一次，PLC 大量重复
            NSUInteger drop = (length - offset > 1) ? (length - offset - 1) : 0;
            if (drop > 0) {
                _droppedBytes += drop;
                _resyncCount++;
                _pendingLossBytes += drop;
                offset += drop;
            }
            break;
        }
        // 找到同步点：丢弃 [offset, sync) 的脏数据，累计丢失量统一折算 PLC
        NSUInteger drop = sync - offset;
        if (drop > 0 || _pendingLossBytes > 0) {
            _droppedBytes += drop;
            _resyncCount++;
            NSUInteger totalLoss = _pendingLossBytes + drop;
            _pendingLossBytes = 0;
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                @"Opus 重同步: 丢弃 %lu 字节脏数据（含跨包累计 %lu），同步点 offset=%lu",
                (unsigned long)totalLoss, (unsigned long)drop, (unsigned long)sync]];
            [self emitPLCFramesForLostBytes:totalLoss];
        }
        offset = sync;
        resyncing = NO;
    }

    // 尾部不足一帧的字节保留到下一包（缓冲修剪由调用方做）
    return offset;
}

/**
 * 在 [from, to) 范围内查找同步锚点 0x4B 0x41 的位置。
 * @return 找到的索引；找不到返回 NSNotFound
 */
- (NSUInteger)findSyncAnchor:(const UInt8 *)bytes from:(NSUInteger)from to:(NSUInteger)to {
    if (to < from + 2) return NSNotFound;
    NSUInteger last = to - 2;   // 最后一个可能的起始位置
    for (NSUInteger i = from; i <= last; i++) {
        if (bytes[i] == OPUS_TOC_BYTE_0 && bytes[i + 1] == OPUS_TOC_BYTE_1) {
            return i;
        }
    }
    return NSNotFound;
}

/**
 * 按丢失字节数折算并输出 PLC 帧（保持 PCM 时间轴与墙钟对齐）。
 * 80 字节 = 1 帧 = 20ms。受 OPUS_PLC_MAX_PER_RESYNC 上限约束。
 */
- (void)emitPLCFramesForLostBytes:(NSUInteger)lostBytes {
    NSUInteger frames = lostBytes / OPUS_FRAME_BYTES;
    if (frames == 0) return;
    if (frames > OPUS_PLC_MAX_PER_RESYNC) {
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
            @"丢失 %lu 字节折算 %lu 帧超过 PLC 上限 %lu，只补 %lu 帧（其余静默跳过）",
            (unsigned long)lostBytes, (unsigned long)frames,
            (unsigned long)OPUS_PLC_MAX_PER_RESYNC, (unsigned long)OPUS_PLC_MAX_PER_RESYNC]];
        frames = OPUS_PLC_MAX_PER_RESYNC;
    }
    for (NSUInteger i = 0; i < frames; i++) {
        _plcFrameCount++;
        [self decodePLCFrame];
    }
}

/** 输出一帧 PLC（packet loss concealment），保持时间轴连续。
 *  frame_size 必须传 20ms 对应的采样数（320@16k）而非 OPUS_MAX_FRAME_SAMPLES——
 *  PLC（data=NULL,len=0）时 libopus 无法从 packet 推断时长，会按 frame_size 参数
 *  输出；传 5760 会解出 120ms 的巨帧，破坏时间轴。 */
- (void)decodePLCFrame {
    if (!self.isRunning || !_decoder || !_pcmBuffer) return;
    int sampleCount = opus_decode(_decoder, NULL, 0, _pcmBuffer,
                                  (opus_int16)(self.sampleRate / 50), 0);
    if (sampleCount < 0) {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:
            @"PLC 帧失败: %s", opus_strerror(sampleCount)]];
        return;
    }
    if (self.pcmDataBlock) {
        NSUInteger pcmBytes = (NSUInteger)sampleCount * (NSUInteger)self.channelCount * sizeof(opus_int16);
        NSData *pcm = [NSData dataWithBytes:_pcmBuffer length:pcmBytes];
        self.pcmDataBlock(pcm, self.sampleRate, self.channelCount);
    }
}

- (void)decodeSingleFrame:(const UInt8 *)frameData size:(NSUInteger)frameSize {
    int sampleCount = opus_decode(_decoder,
                                  frameData,
                                  (opus_int32)frameSize,
                                  _pcmBuffer,
                                  OPUS_MAX_FRAME_SAMPLES,
                                  0 /* decode_fec */);
    if (sampleCount < 0) {
        // 当前包解码失败：用 PLC 帧替代，保持时间轴连续
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
            @"opus_decode 失败 %s，改用 PLC 帧填补", opus_strerror(sampleCount)]];
        sampleCount = opus_decode(_decoder, NULL, 0, _pcmBuffer,
                                  OPUS_MAX_FRAME_SAMPLES, 0);
        if (sampleCount < 0) {
            [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:
                @"PLC 帧也失败: %s", opus_strerror(sampleCount)]];
            return;
        }
    }

    if (self.pcmDataBlock) {
        NSUInteger pcmBytes = (NSUInteger)sampleCount * (NSUInteger)self.channelCount * sizeof(opus_int16);
        NSData *pcm = [NSData dataWithBytes:_pcmBuffer length:pcmBytes];
        self.pcmDataBlock(pcm, self.sampleRate, self.channelCount);
    }
}

@end
