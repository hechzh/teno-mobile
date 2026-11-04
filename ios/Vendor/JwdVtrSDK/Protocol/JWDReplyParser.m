//
//  JWDReplyParser.m
//  JwdVtrSDK
//

#import "JWDReplyParser.h"
#import "JWDSdkLogger.h"
#import "JWDTool.h"
#import "JWDFileInfo.h"
#import "JWDWifiInfo.h"
#import "JWDMp3Decoder.h"
#import "JWDOpusDecoder.h"
#import "JWDWifiConnector.h"
#import <ifaddrs.h>
#import <arpa/inet.h>

static NSString *const TAG = @"JWDReplyParser";
static NSString *const SOCKET_HOST = @"192.168.200.1";
static const int SOCKET_PORT = 8475;
static const int MAX_SOCKET_RETRY = 10; // Socket 连接最大重试次数（不含首次连接，ENETDOWN 需要多次重试等待网络接口就绪）
static const NSTimeInterval SOCKET_RETRY_DELAY = 2.0; // 重试间隔（秒），等待设备 WiFi AP 完全就绪

#pragma mark - WiFi 文件传输终结判定常量（对齐 Android jwdvtrlib 2026-09-17 改动）

/// 固件在每个 WiFi 传输文件末尾附加的结束标记（协议事实 F2，不可变更）
static const uint8_t kWifiEndMarker[5] = {0xBA, 0x5A, 0x02, 0x8F, 0x04};
static const NSUInteger kWifiEndMarkerLen = 5;

/// 透传数据时扣留的末字节数（需求文档第 9 节建议取 4，此处取 5 —— 等于标记全长）。
///
/// 取 5 而非 4 的理由：扣留 k 字节可保证「跨 TCP 包分割的标记」在被识别前有 k 字节被留住。
/// 当 k=4 时，若 5 字节标记【整包】落在某个 TCP 包尾部、而此刻 OFF 未到且长度未到（标记不可信，
/// 见 wifiMarkerIsTrustworthy），则包内标记的第 1 字节会先被透传出去，之后无法再剥除，
/// 导致应用层文件多出 1 个脏字节，且终结日志里的 received 与实际落盘长度对不上。
///
/// 取 k=5 后，标记的任何前缀（1~5 字节）都必定完整留在扣留缓冲里，可在终结时一次性剥干净：
///   落盘字节数 ≡ 终结日志的 received（严格满足需求文档 5.4 的「实际数据长度」口径）。
/// 代价仅是应用层数据延迟 ≤5 字节 —— 对文件传输无影响。
static const NSUInteger kWifiHoldBackLen = 5;

/// MCU&OFF 到达后的宽限窗口（秒）。用于吸收 BLE 与 WiFi 尾部数据的时序差（协议事实 F4）。
static const NSTimeInterval kWifiOffGraceInterval = 5.0;

/// 传输模式（对外公开属性 importingFile 的语义）
/// 0 = 空闲 / 1 = BLE 传输中 / 2 = WiFi(Socket) 传输中
static const int kWifiModeBLE = 1;
static const int kWifiModeSocket = 2;

/**
 * WiFi 传输终结的【内部原因】。
 *
 * 注意：三个原因对外统一回调事件码 1（决策 D1），不新增事件码、不新增详情回调（决策 D2）。
 * 区别只体现在日志里 —— 完整性判断下沉到应用层，由应用层对比落盘长度与 onTransStart 的 fileLen。
 */
typedef NS_ENUM(NSUInteger, JWDWifiFinishReason) {
    JWDWifiFinishReasonExact = 0,          ///< 规则1：长度精确对齐（兼容 fileLen / fileLen+5 且尾标记）
    JWDWifiFinishReasonLengthMismatch = 1, ///< 规则2：OFF 已到 + 尾标记命中，但长度不足（中途丢包）
    JWDWifiFinishReasonTimeout = 2,        ///< 规则3：OFF 宽限期耗尽仍未对齐（尾包丢 / 全丢）
};

static NSString *JWDWifiFinishReasonText(JWDWifiFinishReason reason) {
    switch (reason) {
        case JWDWifiFinishReasonExact:          return @"精确完成";
        case JWDWifiFinishReasonLengthMismatch: return @"长度不符(中途丢包)";
        case JWDWifiFinishReasonTimeout:        return @"超时兜底(尾包丢/全丢)";
    }
    return @"未知";
}

/**
 * WiFi 传输状态机的线程收敛。
 *
 * 状态机的输入来自两条不同链路：
 *   - Socket 数据：JWDSocketClient 已统一派发到主线程；
 *   - MCU&U&len / MCU&OFF：CoreBluetooth 回调线程，取决于宿主创建 CBCentralManager 时指定的队列。
 *
 * 复合操作（累计长度 / tail5 / offReceived 的读写）必须在同一线程串行执行，否则会丢更新。
 * 这里统一收敛到主线程：已在主线程则同步执行（保持现有的同步回调语义与顺序保证），否则异步排入。
 */
static inline void JWDRunOnMainSerialized(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@interface JWDReplyParser ()
@property (nonatomic, assign, readwrite) BOOL isAuth;
@property (nonatomic, assign, readwrite) BOOL isWifiAccelerated;
@property (nonatomic, strong) NSMutableArray<NSString *> *fileDirList;
@property (nonatomic, strong) NSMutableArray<JWDFileInfo *> *fileList;
@property (nonatomic, strong, nullable) JWDWifiInfo *wifiInfo;
@property (nonatomic, strong, nullable) JWDSocketClient *socketClient;
@property (nonatomic, strong, nullable) NSArray<NSString *> *supportSettings;
@property (nonatomic, copy, nullable) NSString *currentRecordFileName;
@property (nonatomic, assign) long fileLen;
@property (nonatomic, assign) long socketByteLen;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong, nullable) NSTimer *wifiStatusTimer;
@property (nonatomic, assign) int wifiStatusQueryCount; // 轮询次数限制
@property (nonatomic, strong, nullable) JWDMp3Decoder *mp3Decoder;
@property (nonatomic, strong, nullable) JWDOpusDecoder *opusDecoder;
@property (nonatomic, strong, nullable) id<JWDAudioDecoder> activeAudioDecoder; // 当前路由指向 mp3Decoder 或 opusDecoder
@property (nonatomic, assign) JWDAudioDecoderType currentAudioDecoderType; // 默认 JWDAudioDecoderTypeMP3
@property (nonatomic, strong, nullable) JWDWifiConnector *wifiConnector;
@property (nonatomic, assign) BOOL isTargetWifiConnected; // WiFi 热点是否已连接
@property (nonatomic, assign) BOOL isHotspotConnecting;  // 热点连接是否已发起（在途 WIFIS&2 重复应答的幂等守卫）
@property (nonatomic, assign) NSInteger interfacePollAttempts; // 热点 IP 就绪轮询计数（实例方法递归版）
@property (nonatomic, assign) int socketRetryCount; // Socket 连接重试计数
@property (nonatomic, assign) BOOL socketSessionActive; // Socket 加速会话是否活跃（didConnect 后置 YES，手动断开/放弃后置 NO，用于允许断线后自动重连）
@property (nonatomic, assign) BOOL isDeviceWifiActive; // 设备端 WiFi AP 是否活跃（MCU&WIFIO=YES, MCU&WIFIC=NO）
// === BK 标记文件接收状态机（对齐 Android ReplyParser）===
@property (nonatomic, assign) BOOL isReceivingBk; // 是否处于 BK 接收状态（发送 APP&BK 后、收到 MCU&BK&OK/ERR 前）
@property (nonatomic, strong) NSMutableData *bkBuffer; // BK 音频帧累积缓冲
@property (nonatomic, copy, nullable) NSString *currentBkDir; // 当前 BK 请求的文件夹名
@property (nonatomic, copy, nullable) NSString *currentBkFile; // 当前 BK 请求的文件名

// === WiFi 文件传输终结状态机（对齐 Android ReplyParser 2026-09-17 改动）===
// 语义映射：transferMode=importingFile / expectedLen=fileLen / receivedTotal=socketByteLen
@property (nonatomic, assign) BOOL wifiOffReceived;      // 是否已收到本次传输的 MCU&OFF
@property (nonatomic, assign) BOOL wifiTransFinished;    // 本次传输是否已终结（防重入，保证恰好一次回调）
@property (nonatomic, assign) long wifiEmittedLen;       // 已透传给应用层的数据字节数（不含扣留中的字节，用于异常截断）
@property (nonatomic, strong) NSMutableData *wifiTailBuf;     // 累计流的末 5 字节（跨 TCP 包检测结束标记）
@property (nonatomic, strong) NSMutableData *wifiHoldBackBuf; // 扣留的末 4 字节（标记可能跨包，避免污染上层文件）
@property (nonatomic, strong, nullable) NSTimer *wifiGraceTimer; // OFF 宽限计时器
// === 传输 CRC32（杰理方案 MCU&OFF&CRC32）===
// MCU&OFF 到达时解析出的设备侧文件 CRC32（8 位十六进制大写字符串）。
// 仅在随事件 1 派发给应用层时有效；终结派发后立即清空。
@property (nonatomic, copy, nullable) NSString *transferCrc32;
// === 通告前缓冲（杰理时序：Socket 数据可能先于 BLE 的 MCU&U&len 到达）===
// 杰理固件收到 APP&U 后同时走两条路：Socket 推数据（快）+ BLE 回 MCU&U&len（慢）。
// 数据先到而 fileLen 仍为 0 时，暂存到 pendingBuf，等 MCU&U&len 到达后回放。
@property (nonatomic, strong, nullable) NSMutableData *wifiPendingBuf;
@property (nonatomic, strong, nullable) NSArray<NSData *> *wifiPendingChunks; // 回放用的分包快照
@property (nonatomic, assign) BOOL wifiPendingReplaying; // 回放中（避免递归入缓冲）
@end

@implementation JWDReplyParser

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileDirList = [NSMutableArray array];
        _fileList = [NSMutableArray array];
        _isAuth = NO;
        _importingFile = 0;
        _fileLen = 0;
        _socketByteLen = 0;
        _bkBuffer = [NSMutableData dataWithCapacity:1024];
        _isReceivingBk = NO;
        // === WiFi 文件传输终结状态机初始化 ===
        _wifiTailBuf = [NSMutableData dataWithCapacity:kWifiEndMarkerLen];
        _wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
        _wifiOffReceived = NO;
        _wifiTransFinished = NO;
        _wifiEmittedLen = 0;
        _callbackQueue = dispatch_get_main_queue();
        _wifiConnector = [[JWDWifiConnector alloc] init];

        // === 初始化两个解码器（MP3 / Opus），默认路由到 MP3 ===
        // 两者都遵循 JWDAudioDecoder 协议，共享同一 PCM 回调路由。
        // 设备名决定切换：含 "_P" → Opus，否则 → MP3（由 JWDClient 在 onPeripheralConnected 时设置）。
        _mp3Decoder = [[JWDMp3Decoder alloc] initWithSampleRate:16000 channelCount:1];
        _opusDecoder = [[JWDOpusDecoder alloc] initWithSampleRate:16000 channelCount:1];
        _currentAudioDecoderType = JWDAudioDecoderTypeMP3;
        _activeAudioDecoder = _mp3Decoder;

        __weak typeof(self) weakSelf = self;
        JWDPcmDataBlock pcmBlock = ^(NSData *pcmData, int sampleRate, int channelCount) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.recordStateDelegate &&
                [strongSelf.recordStateDelegate respondsToSelector:@selector(onRecordStream:)]) {
                [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"PCM 回调: %lu bytes", (unsigned long)pcmData.length]];
                [strongSelf.recordStateDelegate onRecordStream:pcmData];
            }
        };
        _mp3Decoder.pcmDataBlock = pcmBlock;
        _opusDecoder.pcmDataBlock = pcmBlock;
    }
    return self;
}

#pragma mark - 消息解析

- (void)parseMessage:(NSString *)hexString {
    // 将hex字符串的每个字节转为ASCII字符
    NSArray<NSString *> *hexParts = [hexString componentsSeparatedByString:@" "];
    NSMutableString *resultInfo = [NSMutableString string];
    for (NSString *part in hexParts) {
        if (part.length == 0) continue;
        NSString *ch = [JWDTool hexStringToAsciiString:part];
        [resultInfo appendString:ch];
    }
    
    NSArray<NSString *> *cmds = [resultInfo componentsSeparatedByString:@"&"];
    [JWDSdkLogger logProtocolReceive:TAG protocol:[NSString stringWithFormat:@"%@\n解析后: %@", hexString, resultInfo]];

    // === 录音控制相关 ===
    if ([resultInfo hasPrefix:@"MCU&STA"] || [resultInfo hasPrefix:@"MCU&STO"] ||
        [resultInfo hasPrefix:@"MCU&STE&"] || [resultInfo hasPrefix:@"MCU&RT&"] ||
        [resultInfo hasPrefix:@"MCU&REC&ERR"] || [resultInfo hasPrefix:@"MCU&DISK&ERR"] ||
        [resultInfo hasPrefix:@"MCU&AUTO&STO"] || [resultInfo hasPrefix:@"MCU&AUTO&STA"] ||
        [resultInfo hasPrefix:@"MCU&REC&"]) {
        [self parseRecordCommand:resultInfo cmds:cmds];
    }
    // === 文件管理相关 ===
    // MCU&C 短前缀会误匹配 MCU&CT&（设备时间应答），故 C 分支要求长度 ≥2 段（cmds.count >= 2）
    // 实际上 MCU&C 单独出现就是断点续传指令（MCU&C&LEN），但 MCU&CT& 也以 MCU&C 开头
    // 改用更精确的判断：hasPrefix:@"MCU&C&"]（带 &）避免误伤 CT
    else if ([resultInfo hasPrefix:@"MCU&DIRS"] || [resultInfo hasPrefix:@"MCU&F&"] ||
             [resultInfo hasPrefix:@"MCU&LIST"] || [resultInfo hasPrefix:@"MCU&OFF"] ||
             [resultInfo hasPrefix:@"MCU&C&"] || [resultInfo hasPrefix:@"MCU&D"] ||
             [resultInfo isEqualToString:@"MCU&SHUT"] || [resultInfo isEqualToString:@"MCU&U&ERR"]) {
        [self parseFileCommand:resultInfo cmds:cmds];
    }
    // === WiFi相关 ===
    else if ([resultInfo hasPrefix:@"MCU&WIFIO"] || [resultInfo hasPrefix:@"MCU&WIFIC"] ||
             [resultInfo hasPrefix:@"MCU&WIFI&"] || [resultInfo hasPrefix:@"MCU&WIFIS&"] ||
             [resultInfo hasPrefix:@"MCU&U&WIFI"]) {
        [self parseWifiCommand:resultInfo cmds:cmds];
    }
    // === 文件传输开始（需在WiFi之后判断） ===
    else if ([resultInfo hasPrefix:@"MCU&U&"]) {
        [self parseFileTransferStart:cmds];
    }
    // === 设备信息和设置 ===
    else if ([resultInfo hasPrefix:@"MCU&MAC&"] || [resultInfo hasPrefix:@"MCU&SPA&"] ||
             [resultInfo isEqualToString:@"MCU&T&OK"] || [resultInfo hasPrefix:@"MCU&FW&"] ||
             [resultInfo hasPrefix:@"MCU&WF&"] || [resultInfo hasPrefix:@"MCU&USB&STA"] ||
             [resultInfo hasPrefix:@"MCU&CT&"] ||
             [resultInfo hasPrefix:@"MCU&BAT&"] || [resultInfo hasPrefix:@"MCU&FUNCTION&"] ||
             [resultInfo hasPrefix:@"MCU&SET&"] ||
             (self.currentSettingName && [resultInfo hasPrefix:[NSString stringWithFormat:@"MCU&%@", self.currentSettingName]])) {
        [self parseDeviceInfoCommand:resultInfo cmds:cmds];
    }
    // === OTA（杰理方案 2026-09-30 流控协议）===
    //   App: APP&OTA&len&CRC32 → MCU: MCU&OTA（就绪）
    //   App: 每 32 帧 × 256B × 10ms 一组 → MCU: MCU&OTA&GO（确认续发下一组）
    //   App: APP&OT&OVER → MCU: MCU&OT&OVER（完整接收）/ MCU&OT&ERR&VAL（异常）
    else if ([resultInfo isEqualToString:@"MCU&OTA"]) {
        if (self.otaDelegate && [self.otaDelegate respondsToSelector:@selector(onOtaReceiveReady)]) {
            [self.otaDelegate onOtaReceiveReady];
        }
    } else if ([resultInfo isEqualToString:@"MCU&OTA&GO"]) {
        // 杰理方案流控：设备确认前 32 帧已收妥，可继续发送下一组
        if (self.otaDelegate && [self.otaDelegate respondsToSelector:@selector(onOtaGo)]) {
            [self.otaDelegate onOtaGo];
        }
    } else if ([resultInfo hasPrefix:@"MCU&OTA&"]) {
        // 旧固件帧确认（数字索引）；需在字符串比较 GO 之后，避免 "GO" 被 intValue 误解析为 0
        if (self.otaDelegate && cmds.count > 2) {
            [self.otaDelegate onOtaFrameIndex:[cmds[2] intValue]];
        }
    } else if ([resultInfo isEqualToString:@"MCU&OT&OVER"]) {
        if (self.otaDelegate && [self.otaDelegate respondsToSelector:@selector(onOtaReceiveEnd)]) {
            [self.otaDelegate onOtaReceiveEnd];
        }
    } else if ([resultInfo hasPrefix:@"MCU&OT&ERR"]) {
        // 杰理方案：MCU&OT&ERR&VAL（VAL 为错误码；缺省按未知处理）
        NSInteger code = JWDOtaErrorUnknown;
        if (cmds.count > 3) {
            code = [cmds[3] integerValue];
        }
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"OTA 升级失败 (MCU&OT&ERR, code=%ld)", (long)code]];
        // 唯一错误出口 onOtaErrorWithCode:（2026-10-12 按需求移除 onOtaError 兼容回退；
        // 若 delegate 未实现错误码回调则仅记日志，不派发）
        if (self.otaDelegate && [self.otaDelegate respondsToSelector:@selector(onOtaErrorWithCode:)]) {
            [self.otaDelegate onOtaErrorWithCode:code];
        }
    } else if ([resultInfo hasPrefix:@"MCU&OT&"]) {
        // 兼容旧固件非 OVER 的其他 OT 应答（无错误码）→ 统一走错误码出口，缺省 Unknown
        if (self.otaDelegate && [self.otaDelegate respondsToSelector:@selector(onOtaErrorWithCode:)]) {
            [self.otaDelegate onOtaErrorWithCode:JWDOtaErrorUnknown];
        }
    }
    // === 认证 ===
    else if ([resultInfo hasPrefix:@"MCU&SK&OK"]) {
        self.isAuth = YES;
        if (self.authDelegate) { [self.authDelegate onAuthSuccess]; }
    } else if ([resultInfo hasPrefix:@"MCU&SK&ERR"]) {
        self.isAuth = NO;
        if (self.authDelegate) { [self.authDelegate onAuthFailed]; }
    }
    // === 录音暂停/恢复应答（对应 App 发的 APP&PAU / APP&RESU）===
    else if ([resultInfo isEqualToString:@"MCU&PAUSE"] || [resultInfo isEqualToString:@"MCU&RESUME"]) {
        if (!self.recordStateDelegate) {
            [JWDSdkLogger w:TAG msg:@"recordStateDelegate is nil, 忽略暂停/恢复应答"];
            return;
        }
        if ([resultInfo isEqualToString:@"MCU&PAUSE"]) {
            [JWDSdkLogger i:TAG msg:@"MCU 确认暂停录音 (MCU&PAUSE)"];
            if ([self.recordStateDelegate respondsToSelector:@selector(onRecordPaused)]) {
                [self.recordStateDelegate onRecordPaused];
            }
        } else {
            [JWDSdkLogger i:TAG msg:@"MCU 确认恢复录音 (MCU&RESUME)"];
            if ([self.recordStateDelegate respondsToSelector:@selector(onRecordResumed)]) {
                [self.recordStateDelegate onRecordResumed];
            }
        }
    }
    // === 标记文件传输结束：兼容 MCU&BK&OK 与 APP&BK&OK ===
    else if ([resultInfo isEqualToString:@"MCU&BK&OK"] || [resultInfo isEqualToString:@"APP&BK&OK"]) {
        [self finishFileBk];
    }
    // === 标记文件传输失败：兼容 MCU&BK&ERR / APP&BK&ERR（无错误码 -> 0=通用错误）===
    // 以及 MCU&BK&ERR&N / APP&BK&ERR&N（带错误码：1=非空闲，2=无标记）
    else if ([resultInfo hasPrefix:@"MCU&BK&ERR"] || [resultInfo hasPrefix:@"APP&BK&ERR"]) {
        NSInteger errorCode = 0;
        // 解析错误码（cmds[3] 形如 "1" / "2"）
        if (cmds.count >= 4) {
            errorCode = [cmds[3] integerValue];
        }
        NSString *reason = nil;
        switch (errorCode) {
            case 1:
                reason = @"非空闲状态, 不能获取标记";
                break;
            case 2:
                reason = @"该文件没有标记";
                break;
            default:
                reason = [NSString stringWithFormat:@"MCU 返回 BK&ERR (code=%ld)", (long)errorCode];
                break;
        }
        [self finishFileBkWithError:errorCode reason:reason];
    }
}

#pragma mark - 录音指令解析

- (void)parseRecordCommand:(NSString *)resultInfo cmds:(NSArray<NSString *> *)cmds {
    if (!self.recordStateDelegate) return;
    
    if ([resultInfo hasPrefix:@"MCU&STA"]) {
        // 开始录音
        self.currentRecordFileName = cmds.count > 2 ? cmds[2] : @"";
        if ([self.currentRecordFileName hasPrefix:@"PH"]) {
            [self.recordStateDelegate onRecordStateReply:JWDRecordStatePhoneRecording
                                               fileName:self.currentRecordFileName
                                            currentTime:0];
        } else {
            [self.recordStateDelegate onRecordStateReply:JWDRecordStateNormalRecording
                                               fileName:self.currentRecordFileName
                                            currentTime:0];
        }
        // 2026-09-28：恢复解码器启动（2026-09-23 曾因测试暂时下线）
        [self.activeAudioDecoder start];
    } else if ([resultInfo hasPrefix:@"MCU&STO"]) {
        // 停止录音
        [self.activeAudioDecoder stop];
        [self.recordStateDelegate onRecordStateReply:JWDRecordStateStopped
                                           fileName:self.currentRecordFileName
                                        currentTime:0];
        self.currentRecordFileName = nil;
    } else if ([resultInfo hasPrefix:@"MCU&STE&"]) {
        int status = cmds.count > 2 ? [cmds[2] intValue] : 0;
        [self.recordStateDelegate onRecordStateCheck:status];
    } else if ([resultInfo hasPrefix:@"MCU&RT&"]) {
        // 设备主动上报录音中状态
        self.currentRecordFileName = cmds.count > 2 ? cmds[2] : @"";
        long time = cmds.count > 3 ? [cmds[3] longLongValue] : 0;
        if ([self.currentRecordFileName hasPrefix:@"PH"]) {
            [self.recordStateDelegate onRecordStateReply:JWDRecordStatePhoneRecorded
                                               fileName:self.currentRecordFileName
                                            currentTime:time];
        } else {
            [self.recordStateDelegate onRecordStateReply:JWDRecordStateNormalRecorded
                                               fileName:self.currentRecordFileName
                                            currentTime:time];
        }
        // 2026-09-28：恢复解码器启动（2026-09-23 曾因测试暂时下线）
        [self.activeAudioDecoder start];
    } else if ([resultInfo hasPrefix:@"MCU&REC&ERR"]) {
        [self.recordStateDelegate onRecordStateReply:JWDRecordStateNormalError
                                           fileName:self.currentRecordFileName
                                        currentTime:0];
    } else if ([resultInfo hasPrefix:@"MCU&REC&"]) {
        NSString *mode = cmds.count > 2 ? cmds[2] : @"";
        [self.recordStateDelegate onRecordMode:[mode isEqualToString:@"CALL"] ? 1 : 0];
    } else if ([resultInfo hasPrefix:@"MCU&DISK&ERR"]) {
        [self.recordStateDelegate onRecordStateReply:JWDRecordStateStorageFull
                                           fileName:self.currentRecordFileName
                                        currentTime:0];
    } else if ([resultInfo hasPrefix:@"MCU&AUTO&STO"]) {
        [self.recordStateDelegate onRecordStateReply:JWDRecordStateStopped
                                           fileName:self.currentRecordFileName
                                        currentTime:0];
    } else if ([resultInfo hasPrefix:@"MCU&AUTO&STA"]) {
        self.currentRecordFileName = cmds.count > 3 ? cmds[3] : @"";
        if ([self.currentRecordFileName hasPrefix:@"PH"]) {
            [self.recordStateDelegate onRecordStateReply:JWDRecordStatePhoneRecording
                                               fileName:self.currentRecordFileName
                                            currentTime:0];
        } else {
            [self.recordStateDelegate onRecordStateReply:JWDRecordStateNormalRecording
                                               fileName:self.currentRecordFileName
                                            currentTime:0];
        }
    }
}

#pragma mark - 文件管理指令解析

- (void)parseFileCommand:(NSString *)resultInfo cmds:(NSArray<NSString *> *)cmds {
    if (!self.fileMgrDelegate) {
        [JWDSdkLogger e:TAG msg:@"fileMgrDelegate is nil"];
        return;
    }
    
    if ([resultInfo hasPrefix:@"MCU&DIRS_SUM"]) {
        int sum = cmds.count > 2 ? [cmds[2] intValue] : 0;
        NSArray<NSString *> *dirs = [NSArray arrayWithArray:self.fileDirList];
        [self.fileMgrDelegate onFileDirs:dirs total:sum];
        [self.fileDirList removeAllObjects];
    } else if ([resultInfo hasPrefix:@"MCU&DIRS"]) {
        NSString *dirName = cmds.count > 2 ? cmds[2] : @"";
        [self.fileDirList addObject:dirName];
    } else if ([resultInfo hasPrefix:@"MCU&LIST"]) {
        int len = cmds.count > 2 ? [cmds[2] intValue] : 0;
        NSArray<JWDFileInfo *> *files = [NSArray arrayWithArray:self.fileList];
        [self.fileMgrDelegate onDirFiles:files dir:self.currentDir ?: @"" total:len];
        [self.fileList removeAllObjects];
        self.currentDir = nil;
    } else if ([resultInfo hasPrefix:@"MCU&F&"]) {
        self.currentDir = cmds.count > 2 ? cmds[2] : @"";
        NSString *fileName = cmds.count > 3 ? cmds[3] : @"";
        long fileDur = cmds.count > 4 ? [cmds[4] longLongValue] : 0;
        JWDFileInfo *info = [[JWDFileInfo alloc] initWithFileName:fileName duration:fileDur];
        [self.fileList addObject:info];
    } else if ([resultInfo isEqualToString:@"MCU&U&ERR"]) {
        if (self.importingFile != 0) {
            self.importingFile = 0;
            // 传输出错：必须一并复位 WiFi 终结状态机，否则残留的宽限计时器可能事后误回调事件 1
            [self resetWifiTransferStateKeepMode];
            [self emitTransEvent:-1];
        } else {
            // 空闲态的 U&ERR：无传输可失败，不派发 -1（与 MCU&SHUT 同理，防误报）
            [JWDSdkLogger d:TAG msg:@"空闲态收到 MCU&U&ERR，忽略，不派发事件 -1"];
        }
    } else if ([resultInfo hasPrefix:@"MCU&OFF"]) {
        // 杰理方案：MCU&OFF&CRC32（CRC32 为 8 位十六进制字符串，如 FAFAFAFA）。
        // 兼容旧固件无 CRC 段的裸 MCU&OFF（cmds.count == 2）。解析后存入 transferCrc32，
        // 随传输完成事件（事件 1）一并派发给应用层做完整性校验。
        if (cmds.count > 2 && [cmds[2] length] == 8) {
            self.transferCrc32 = [cmds[2] uppercaseString];
        }
        [self handleTransferOff];
    } else if ([resultInfo isEqualToString:@"MCU&SHUT"]) {
        if (self.importingFile != 0) {
            // 传输中的人为中断：复位并回调事件 2（语义不变）
            self.importingFile = 0;
            // 同步清空终结状态与宽限计时器
            [self resetWifiTransferStateKeepMode];
            [self emitTransEvent:2];
        } else {
            // 空闲态收到 MCU&SHUT：这是 switchToWifiChannel / closeWifi 前置的
            // APP&SHUT 清理指令的【无条件应答】——没有传输可被中断。
            // 不派发事件 2，否则应用层会误报「传输失败」。
            [JWDSdkLogger d:TAG msg:@"空闲态收到 MCU&SHUT（清理指令应答），忽略，不派发事件 2"];
        }
    } else if ([resultInfo hasPrefix:@"MCU&C"]) {
        self.importingFile = 1;
        long len = cmds.count > 2 ? [cmds[2] longLongValue] : 0;
        [self.fileMgrDelegate onResumeBreak:len fileName:self.currentResumeFile ?: @""];
    } else if ([resultInfo hasPrefix:@"MCU&D"]) {
        [self.fileMgrDelegate onDeletedFile:1 fileName:self.currentDelFileName ?: @""];
    }
}

#pragma mark - WiFi指令解析

- (void)parseWifiCommand:(NSString *)resultInfo cmds:(NSArray<NSString *> *)cmds {
    if (!self.wifiStatusDelegate) {
        [JWDSdkLogger e:TAG msg:@"wifiStatusDelegate is nil"];
        return;
    }
    
    if ([resultInfo hasPrefix:@"MCU&WIFIO"]) {
        [self.wifiStatusDelegate onWifiStatus:1];
        self.isDeviceWifiActive = YES; // 设备 WiFi 已开启
        // 启动 WiFi 状态轮询（对齐 Android startWifiStatusQuery）
        [self startWifiStatusQuery];
    } else if ([resultInfo hasPrefix:@"MCU&WIFIC"]) {
        // 启动阶段竞态处理（2026-10-08，杰理固件实测）：
        //   switchToWifiChannel 三连发（APP&SHUT → APP&WIFI → APP&WIFIO），设备对
        //   APP&SHUT 的应答是先回 MCU&WIFIC（关 WiFi）再回 MCU&SHUT，随后才应答
        //   MCU&WIFIO（重开 WiFi）。若 MCU&WIFIC 晚于 APP&WIFIO 到达，会把
        //   openWifi 刚设置的 isWifiAccelerationUserInitiated 复位为 NO，导致后续
        //   MCU&WIFIS&2 的连接条件（用户意图 && status==2）永不成立，轮询空转直到
        //   设备超时自动关 WiFi。
        //   判定：用户已发起加速 且 热点/Socket 均未连接（加速链路从未建立）→ 这是
        //   启动序列内 SHUT 先导应答的正常"先关后开"时序，保留用户意图，
        //   不按"设备关闭 WiFi"处理，等待 MCU&WIFIO 重开。
        BOOL accelerationEstablished = self.isTargetWifiConnected ||
                                       (self.socketClient && self.socketClient.isConnected);
        BOOL startupPhaseWific = self.isWifiAccelerationUserInitiated && !accelerationEstablished;

        [self.wifiStatusDelegate onWifiStatus:0];
        self.isDeviceWifiActive = NO; // 设备 WiFi 已关闭
        // 停止轮询并重置状态
        [self stopWifiStatusQuery];
        self.isWifiAccelerated = NO;
        self.isTargetWifiConnected = NO;
        self.isHotspotConnecting = NO; // 在途的热点连接随会话终结一并复位

        if (startupPhaseWific) {
            [JWDSdkLogger i:TAG msg:@"启动阶段收到 MCU&WIFIC（APP&SHUT 先导应答），保留加速意图，等待 MCU&WIFIO 重开 WiFi"];
            // 防御性清理连接资源（此阶段本就未连接，均为空操作）
            [self disconnectSocket];
            [self.wifiConnector disconnectHotspot];
            return;
        }

        // 已建立阶段：设备真的关闭了 WiFi —— 清意图 / 断热点 / 按需通知 UI（原逻辑）
        BOOL wasUserInitiated = self.isWifiAccelerationUserInitiated;
        self.isWifiAccelerationUserInitiated = NO;
        [self disconnectSocket];
        // 断开 WiFi 热点（对齐 Android wifiConnectUtil.unbindNetwork）
        // 同时设置取消标志，使正在进行的 applyConfiguration completion 回调失效
        [self.wifiConnector disconnectHotspot];
        [JWDSdkLogger i:TAG msg:@"WiFi 已关闭，热点已断开"];
        // 启动阶段被中断：通知 UI 重置按钮状态（Socket 已连接时由 disconnectSocket → onSocketDisconnected 处理）
        if (wasUserInitiated) {
            if (self.socketStatusDelegate && [self.socketStatusDelegate respondsToSelector:@selector(onSocketConnectFailed:)]) {
                [self.socketStatusDelegate onSocketConnectFailed:@"WiFi 加速启动失败：设备 WiFi 已关闭"];
            }
        }
    } else if ([resultInfo hasPrefix:@"MCU&WIFI&"]) {
        JWDWifiInfo *info = [[JWDWifiInfo alloc] init];
        info.ssid = cmds.count > 2 ? cmds[2] : @"";
        info.password = cmds.count > 3 ? cmds[3] : @"";
        self.wifiInfo = info;
        [self.wifiStatusDelegate onWifiInfo:info];
    } else if ([resultInfo hasPrefix:@"MCU&WIFIS&"]) {
        int status = cmds.count > 2 ? [cmds[2] intValue] : 0;
        [self.wifiStatusDelegate onWifiStatus:status];
        [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"WiFi 状态查询结果: %d", status]];
        
        // status == 1: WiFi 正在开启中，继续轮询等待 status == 2
        // status == 2: WiFi 已就绪，停止轮询并连接热点
        if (status == 1) {
            [JWDSdkLogger i:TAG msg:@"WiFi 正在开启中，继续轮询..."];
            return;
        }
        
        // 仅当用户主动发起 WiFi 加速且 status == 2 时，才连接热点和 Socket
        if (self.isWifiAccelerationUserInitiated && status == 2) {
            [self stopWifiStatusQuery];

            // 幂等守卫（2026-10-09 真机日志）：轮询期间可能有多个 WIFIS&2 应答在途
            // （stop 只能停未来的轮询，在途应答仍会到达），重复 applyConfiguration
            // 会打断进行中的 DHCP 流程，加剧"热点连接成功但拿不到 IP"。
            // 首个应答发起连接后，后续重复应答直接忽略，直到连接结果落地。
            if (self.isHotspotConnecting) {
                [JWDSdkLogger w:TAG msg:@"热点连接已在进行中, 忽略重复的 WIFIS&2 应答"];
                return;
            }

            // 使用 MCU&WIFI 返回的 SSID 和密码连接 WiFi 热点
            if (self.wifiInfo && self.wifiInfo.ssid.length > 0) {
                self.isHotspotConnecting = YES;
                [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"WiFi 就绪，开始连接热点: %@", self.wifiInfo.ssid]];
                [self.wifiConnector connectToHotspotWithSSID:self.wifiInfo.ssid
                                                    password:self.wifiInfo.password
                                                  completion:^(BOOL success, NSString * _Nullable error) {
                    self.isHotspotConnecting = NO;
                    if (success) {
                        if (!self.isDeviceWifiActive) {
                            [JWDSdkLogger w:TAG msg:@"iOS 报告热点连接成功，但设备 WiFi 已关闭，放弃连接 Socket"];
                            self.isTargetWifiConnected = NO;
                            [self.wifiConnector disconnectHotspot];
                            if (self.socketStatusDelegate && [self.socketStatusDelegate respondsToSelector:@selector(onSocketConnectFailed:)]) {
                                [self.socketStatusDelegate onSocketConnectFailed:@"WiFi 加速启动失败：设备 WiFi 已关闭"];
                            }
                            return;
                        }
                        if (!self.isTargetWifiConnected) {
                            [JWDSdkLogger i:TAG msg:@"WiFi 热点连接成功，等待网络接口获取 IP 后建立 Socket 连接"];
                            self.isTargetWifiConnected = YES;
                            [self waitForHotspotInterfaceThenConnectSocket];
                        }
                    } else {
                        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"WiFi 热点连接失败: %@", error]];
                        self.isTargetWifiConnected = NO;
                        if (self.isDeviceWifiActive) {
                            if (self.socketStatusDelegate && [self.socketStatusDelegate respondsToSelector:@selector(onSocketConnectFailed:)]) {
                                [self.socketStatusDelegate onSocketConnectFailed:[NSString stringWithFormat:@"WiFi 热点连接失败: %@", error]];
                            }
                        }
                    }
                }];
            } else {
                [JWDSdkLogger e:TAG msg:@"WiFi SSID 信息为空，无法连接热点"];
            }
        }
    } else if ([resultInfo hasPrefix:@"MCU&U&WIFI"]) {
        [self.wifiStatusDelegate onWifiStatus:8];
    }
}

/**
 * 等待热点网络接口就绪（拿到 192.168.200.x 的 IPv4 地址）后再连接 Socket。
 *
 * 背景（2026-10-09 真机日志定案）：NEHotspotConfiguration 回调"成功"时，
 * 网卡往往尚未完成 DHCP —— 固定 1 秒延时不够（实测 IP 拿到要 4~10 秒），
 * 提前发起的 Socket 全部 ENETDOWN，靠重试硬扛浪费 4 次尝试。
 * 改为轮询接口地址（0.5s 一次，最多 20s），地址出现即连。
 *
 * 实现说明：用实例方法递归 + attempts 属性实现轮询，不用 block 自引用
 * （`void (^poll)(void) = ^{ ... poll() ... }` 捕获的是初始化前的无效栈地址，
 * block 拷贝到堆后跳转垃圾指针 → EXC_BREAKPOINT，真机已踩）。
 */
- (void)waitForHotspotInterfaceThenConnectSocket {
    self.interfacePollAttempts = 0;
    [self pollHotspotInterfaceOnce];
}

- (void)pollHotspotInterfaceOnce {
    if (!self.isTargetWifiConnected) {
        [JWDSdkLogger w:TAG msg:@"等待热点 IP 期间热点已断开，放弃连接 Socket"];
        return;
    }
    if ([self hotspotInterfaceReady]) {
        [JWDSdkLogger i:TAG msg:@"热点接口已获取 IP，开始建立 Socket 连接"];
        [self connectSocket];
        return;
    }
    self.interfacePollAttempts++;
    if (self.interfacePollAttempts >= 40) {   // 0.5s × 40 = 20s 上限
        [JWDSdkLogger e:TAG msg:@"等待热点 IP 超时（20s），仍尝试连接 Socket（依赖后续重试）"];
        [self connectSocket];
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf pollHotspotInterfaceOnce];
    });
}

/// 热点网络接口是否已获得 192.168.200.x 的 IPv4 地址
- (BOOL)hotspotInterfaceReady {
    struct ifaddrs *ifap = NULL;
    if (getifaddrs(&ifap) != 0) return NO;
    BOOL ready = NO;
    for (struct ifaddrs *ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL || ifa->ifa_addr->sa_family != AF_INET) continue;
        char addrBuf[INET_ADDRSTRLEN] = {0};
        const char *addr = inet_ntop(AF_INET,
                                     &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr,
                                     addrBuf, sizeof(addrBuf));
        if (addr && strncmp(addr, "192.168.200.", 12) == 0) {
            ready = YES;
            break;
        }
    }
    freeifaddrs(ifap);
    return ready;
}

#pragma mark - 文件传输开始（含通道判定修复）

- (void)parseFileTransferStart:(NSArray<NSString *> *)cmds {
    long len = cmds.count > 2 ? [cmds[2] longLongValue] : 0;
    JWDRunOnMainSerialized(^{
        [self beginTransferWithExpectedLen:len];
    });
}

/**
 * 新文件传输开始（对应 Android ReplyParser 的 MCU&U&len 分支）。
 *
 * ⚠ 通道判定修复（2026-09-17 真机事故）：
 *   必须基于 Socket 的【实际连接状态】判定，不能只看 importingFile 是否为 0。
 *   多文件 WiFi 连发时，上一个文件终结已把 importingFile 复位为 0，但 Socket 仍然连着；
 *   此时若仅按标志判定会误判为 BLE 通道，导致 MCU&OFF 走 BLE 分支立即回调「完成」，
 *   而 WiFi 链路还有在途数据 → 文件被截断保存，迟到数据再触发一次完成回调。
 */
- (void)beginTransferWithExpectedLen:(long)len {
    // 1) 多文件连发保护：强制取消上一文件可能残留的宽限计时器，并复位全部终结状态
    [self cancelWifiGraceTimer];
    self.wifiOffReceived = NO;
    self.wifiTransFinished = NO;
    self.wifiTailBuf = [NSMutableData dataWithCapacity:kWifiEndMarkerLen];
    self.wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
    self.fileLen = len;
    self.socketByteLen = 0;
    self.wifiEmittedLen = 0;
    self.transferCrc32 = nil; // 清掉上一次传输残留的 CRC32（杰理方案）

    // 2) 仅在空闲态判定通道；非空闲（连发且未终结）时保持既有模式，避免中途翻转
    if (self.importingFile == 0) {
        BOOL socketConnected = (self.socketClient && self.socketClient.isConnected);
        self.importingFile = socketConnected ? kWifiModeSocket : kWifiModeBLE;
        [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
                                 @"文件传输开始: file=%@, len=%ld, 通道=%@ (socketConnected=%@)",
                                 self.currentDownloadFile ?: @"", len,
                                 self.importingFile == kWifiModeSocket ? @"WiFi" : @"BLE",
                                 socketConnected ? @"YES" : @"NO"]];
    } else {
        [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
                                 @"文件传输开始: file=%@, len=%ld, 沿用当前通道=%d（连发场景）",
                                 self.currentDownloadFile ?: @"", len, self.importingFile]];
    }

    // 3) 通知应用层记录预告长度，用于传输结束后的完整性校验（决策 D1/D2）
    if (self.fileMgrDelegate) {
        [self.fileMgrDelegate onTransStart:self.currentDownloadFile ?: @"" fileLen:len];
    }

    // 4) 通告前缓冲回放（杰理时序）：若 MCU&U&len 到达前 Socket 已先推过数据，
    //    此刻预告长度就位，把暂存的分包按原始边界逐包回放走正常处理路径
    //    （含结束标记检测 / 三规则终结），对后续逻辑完全透明。
    if (self.wifiPendingChunks.count > 0) {
        NSArray<NSData *> *chunks = self.wifiPendingChunks;
        NSUInteger totalBytes = self.wifiPendingBuf.length;
        [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
                                 @"MCU&U&len 到达, 回放通告前缓冲: %lu 包 / %lu 字节 (file=%@, len=%ld)",
                                 (unsigned long)chunks.count, (unsigned long)totalBytes,
                                 self.currentDownloadFile ?: @"", len]];
        self.wifiPendingBuf = nil;
        self.wifiPendingChunks = nil;
        self.wifiPendingReplaying = YES;
        for (NSData *chunk in chunks) {
            [self handleWifiSocketData:chunk];
        }
        self.wifiPendingReplaying = NO;
    }
}

#pragma mark - WiFi 文件传输终结状态机

#pragma mark · tail5 滑动窗口（跨 TCP 包检测结束标记）

/// 把数据包并入「末 5 字节」滑动窗口。无论 MCU&OFF 是否被 TCP 切成几段，标记都能被检出。
- (void)wifiAppendTail:(NSData *)data {
    [self.wifiTailBuf appendData:data];
    if (self.wifiTailBuf.length > kWifiEndMarkerLen) {
        NSUInteger excess = self.wifiTailBuf.length - kWifiEndMarkerLen;
        [self.wifiTailBuf replaceBytesInRange:NSMakeRange(0, excess) withBytes:NULL length:0];
    }
}

/// 当前累计流的末 5 字节是否为固件结束标记 BA 5A 02 8F 04
- (BOOL)wifiTailIsEndMarker {
    if (self.wifiTailBuf.length != kWifiEndMarkerLen) return NO;
    return memcmp(self.wifiTailBuf.bytes, kWifiEndMarker, kWifiEndMarkerLen) == 0;
}

/**
 * 标记「信任条件」（防 MP3 裸数据误判）。
 *
 * 只有在 OFF 已到达，或累计长度已达到预告值时，尾部命中标记才被当作终结依据。
 * 普通数据阶段（长度未到且 OFF 未到）即使尾部巧合出现同序列字节，也只作为普通数据透传。
 */
- (BOOL)wifiMarkerIsTrustworthy {
    if (![self wifiTailIsEndMarker]) return NO;
    return (self.wifiOffReceived || self.socketByteLen >= self.fileLen);
}

/**
 * 是否为杰理 _P 设备（蓝牙名含 "_P"，Opus 机型）。
 * 判定口径与解码器路由一致：BLE 连接时按设备名设置 currentAudioDecoderType，
 * 这里直接读该状态，避免重复解析设备名导致口径漂移。
 * _P 设备的 WiFi 文件传输遵循 2026-10-10 固件契约：
 * MCU&OFF(&CRC32) 一定在 socket 字节全部发完之后到达，是完成信号的唯一权威。
 */
- (BOOL)isJieliPDevice {
    return (self.currentAudioDecoderType == JWDAudioDecoderTypeOpus);
}

/// 规则1 判定：长度精确对齐（兼容无标记的 received==expected，与 received==expected+5 且尾标记）
- (BOOL)wifiIsExactlyAligned {
    if (self.socketByteLen == self.fileLen) return YES;
    if (self.socketByteLen == (long)(self.fileLen + kWifiEndMarkerLen) && [self wifiTailIsEndMarker]) return YES;
    return NO;
}

#pragma mark · 数据透传（hold-back 缓冲，规避标记字节残留在应用层文件）

/// 非终结路径：透传数据但扣留末 kWifiHoldBackLen 字节，待后续确认是否成标记再决定 flush 或剥除
- (void)wifiForwardStreamData:(NSData *)data {
    NSMutableData *buf = [NSMutableData dataWithData:self.wifiHoldBackBuf];
    [buf appendData:data];
    NSUInteger keep = MIN(kWifiHoldBackLen, buf.length);
    NSUInteger emitLen = buf.length - keep;
    if (emitLen > 0) {
        [self wifiEmit:buf length:emitLen];
    }
    self.wifiHoldBackBuf = [[buf subdataWithRange:NSMakeRange(emitLen, keep)] mutableCopy];
}

/// 终结路径（有伴随数据包）：扣留缓冲 + 本包合并后 flush，需剥标记时去掉末 5 字节
- (void)wifiEmitFinalWithPacket:(NSData *)packet stripMarker:(BOOL)stripMarker {
    NSMutableData *buf = [NSMutableData dataWithData:self.wifiHoldBackBuf];
    [buf appendData:packet];
    NSUInteger emitLen = buf.length;
    if (stripMarker && emitLen >= kWifiEndMarkerLen) {
        emitLen -= kWifiEndMarkerLen;
    }
    if (emitLen > 0) {
        [self wifiEmit:buf length:emitLen];
    }
    self.wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
}

/// 终结路径（无伴随数据包，如 OFF 到达或宽限期超时）：flush 扣留缓冲。
/// 是否剥除由调用方按需求文档 5.4 的公式判定：尾部命中标记 且 累计长度 != 预告长度。
- (void)wifiFlushHoldBackStrippingMarker:(BOOL)stripMarker {
    NSMutableData *buf = self.wifiHoldBackBuf;
    NSUInteger emitLen = buf.length;
    if (stripMarker && emitLen >= kWifiEndMarkerLen) {
        emitLen -= kWifiEndMarkerLen;
    }
    if (emitLen > 0) {
        [self wifiEmit:buf length:emitLen];
    }
    self.wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
}

/// 需求文档 5.4 的剥离判定：尾部命中标记 且 累计长度 != 预告长度
- (BOOL)wifiShouldStripMarker {
    return [self wifiTailIsEndMarker] && (self.socketByteLen != self.fileLen);
}

/// 异常防御：已超出「预告长度+标记」仍无标记命中 → 按 expectedLen 截断后收尾（不再透传脏数据）
- (void)wifiEmitTruncatedToExpectedLenWithPacket:(NSData *)packet {
    [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                             @"WiFi 数据超出预告长度且未命中结束标记, 按 expectedLen 截断: received=%ld, expected=%ld",
                             self.socketByteLen, self.fileLen]];
    NSMutableData *buf = [NSMutableData dataWithData:self.wifiHoldBackBuf];
    [buf appendData:packet];
    long remaining = self.fileLen - self.wifiEmittedLen;
    NSUInteger emitLen = (remaining > 0) ? (NSUInteger)MIN((long)buf.length, remaining) : 0;
    if (emitLen > 0) {
        [self wifiEmit:buf length:emitLen];
    }
    self.wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
}

/// 统一出口：真正把数据交给应用层
- (void)wifiEmit:(NSData *)buf length:(NSUInteger)length {
    if (!self.fileMgrDelegate || length == 0) return;
    NSData *payload = (length == buf.length) ? buf : [buf subdataWithRange:NSMakeRange(0, length)];
    self.wifiEmittedLen += length;
    [self.fileMgrDelegate onFileData:payload fileName:self.currentDownloadFile ?: @""];
}

#pragma mark · 结束指令 MCU&OFF

- (void)handleTransferOff {
    JWDRunOnMainSerialized(^{
        if (self.importingFile == kWifiModeBLE) {
            // —— BLE 传输路径：对外行为完全不变（事件码 1）——
            self.importingFile = 0;
            // 双保险：即使本该走 WiFi 分支却误入 BLE，也要同步终结 WiFi 状态，
            // 把后续迟到数据挡在门外，杜绝二次回调（边界场景 9）
            self.wifiTransFinished = YES;
            [self resetWifiTransferStateKeepMode];
            [self emitTransEvent:1];
            return;
        }

        if (self.importingFile == kWifiModeSocket) {
            // —— WiFi 传输路径：把 OFF 从「被忽略的信号」升级为终结信号 ——
            if (self.wifiTransFinished) {
                // 数据已先自证终结，OFF 迟到：静默忽略，保证恰好一次回调（边界场景 5/6）
                [JWDSdkLogger d:TAG msg:@"WiFi 文件传输已终结, MCU&OFF 迟到, 仅作确认忽略"];
                return;
            }
            if ([self wifiIsExactlyAligned]) {
                // OFF 到达时刻恰好已满足规则1
                [self wifiFlushHoldBackStrippingMarker:[self wifiShouldStripMarker]];
                [self finishWifiTransferWithReason:JWDWifiFinishReasonExact];
                return;
            }
            if (![self isJieliPDevice] && [self wifiTailIsEndMarker]) {
                // 规则2 即时判定：OFF 已到 + 流末已命中结束标记（标记先于 OFF 到达的中途丢包场景）。
                // 此时设备已确认发送完毕且标记在场，无需再等宽限期，立即终结。
                // _P 设备无 5 字节结束标记，不走此分支，交给宽限期等数据对齐。
                [self wifiFlushHoldBackStrippingMarker:YES];
                [self finishWifiTransferWithReason:JWDWifiFinishReasonLengthMismatch];
                return;
            }
            // 进入宽限期：等 WiFi 尾部数据（含 TCP 重传）在 5 秒内追上来。
            // _P 设备：OFF 一定晚于全部字节（固件契约），宽限期内数据对齐即终结
            //（对齐检查复用 wifiGraceTimerFired / 逐包重估路径）。
            self.wifiOffReceived = YES;
            [self scheduleWifiGraceTimer];
            return;
        }

        [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"空闲态收到 MCU&OFF, 忽略 (importingFile=%d)", self.importingFile]];
    });
}

#pragma mark · OFF 宽限计时器

- (void)scheduleWifiGraceTimer {
    [self cancelWifiGraceTimer];
    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:
                             @"MCU&OFF 已到达, 启动 %.0fs 宽限期等待 WiFi 尾部数据 (file=%@)",
                             kWifiOffGraceInterval, self.currentDownloadFile ?: @""]];
    __weak typeof(self) weakSelf = self;
    self.wifiGraceTimer = [NSTimer scheduledTimerWithTimeInterval:kWifiOffGraceInterval
                                                          repeats:NO
                                                            block:^(NSTimer * _Nonnull timer) {
        [weakSelf wifiGraceTimerFired];
    }];
}

- (void)cancelWifiGraceTimer {
    if (self.wifiGraceTimer) {
        [self.wifiGraceTimer invalidate];
        self.wifiGraceTimer = nil;
    }
}

- (void)wifiGraceTimerFired {
    self.wifiGraceTimer = nil;
    if (self.wifiTransFinished) return;
    if ([self wifiIsExactlyAligned]) {
        [self wifiFlushHoldBackStrippingMarker:[self wifiShouldStripMarker]];
        [self finishWifiTransferWithReason:JWDWifiFinishReasonExact];
        return;
    }
    if ([self wifiTailIsEndMarker]) {
        // 规则2：宽限期内数据到齐了标记但长度仍不足（中途丢包）→ 剥标记终结
        [self wifiFlushHoldBackStrippingMarker:YES];
        [self finishWifiTransferWithReason:JWDWifiFinishReasonLengthMismatch];
        return;
    }
    // 规则3：宽限期耗尽，长度与标记均未对齐（尾包丢失或全丢）→ 超时兜底终结
    [self finishWifiTransferWithReason:JWDWifiFinishReasonTimeout];
}

#pragma mark · 统一收尾

/**
 * 所有 WiFi 终结路径的唯一出口（对应 Android finishWifiTransfer）。
 *
 * 保证三件事：
 *  1. 恰好一次回调 —— 数据路径与宽限计时器路径可能并发触发，靠 wifiTransFinished 防重入；
 *  2. 对外统一事件码 1 —— 无论内部原因是精确完成 / 中途丢包 / 超时兜底（决策 D1）；
 *  3. 内部原因与长度证据记入日志 —— 应用层据此自行判断完整性（决策 D2）。
 */
- (void)finishWifiTransferWithReason:(JWDWifiFinishReason)reason {
    if (self.wifiTransFinished) return;
    self.wifiTransFinished = YES;
    [self cancelWifiGraceTimer];

    // 取快照（随后状态即被复位）
    long expected = self.fileLen;
    long received = self.socketByteLen;
    BOOL markerSeen = [self wifiTailIsEndMarker];
    BOOL off = self.wifiOffReceived;
    NSString *file = self.currentDownloadFile ?: @"";

    // 标记剥离 + 扣留缓冲 flush（必须先于状态复位）
    // 伴随数据包到达的路径已在 wifiEmitFinalWithPacket: 中透传完毕，此处扣留缓冲为空，flush 为幂等空操作
    BOOL stripMarker = [self wifiShouldStripMarker];
    [self wifiFlushHoldBackStrippingMarker:stripMarker];
    long actualDataLen = received - (stripMarker ? (long)kWifiEndMarkerLen : 0);

    // 终结证据日志：格式对齐 Android（需求文档 11.2），便于跨端排查对照
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
                             @"wifi 文件传输终结: 内部原因=%@, expected=%ld, received=%ld, markerSeen=%@, offReceived=%@, file=%@",
                             JWDWifiFinishReasonText(reason), expected, actualDataLen,
                             markerSeen ? @"true" : @"false", off ? @"true" : @"false", file]];

    // 复位全部传输状态（宽限计时器已在上一步取消）
    self.importingFile = 0;
    self.wifiOffReceived = NO;
    self.wifiTailBuf = [NSMutableData dataWithCapacity:kWifiEndMarkerLen];
    self.wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
    self.fileLen = 0;
    self.socketByteLen = 0;
    self.wifiEmittedLen = 0;

    [self emitTransEvent:1];
}

/**
 * 统一派发传输事件（杰理方案扩展：事件 1 携带设备上报的 CRC32）。
 *
 * 优先调用新回调 onTransEvent:crc32:（应用层可据此做完整性校验）；
 * 委托未实现新回调时回退旧回调 onTransEvent:，保证向后兼容。
 * 事件 1 派发后清空 transferCrc32，避免残留到下一次传输。
 */
- (void)emitTransEvent:(int)event {
    if (!self.fileMgrDelegate) return;
    NSString *crc32 = (event == 1) ? self.transferCrc32 : nil;
    if ([self.fileMgrDelegate respondsToSelector:@selector(onTransEvent:crc32:)]) {
        [self.fileMgrDelegate onTransEvent:event crc32:crc32];
    } else {
        [self.fileMgrDelegate onTransEvent:event];
    }
    self.transferCrc32 = nil;
}

/**
 * 复位 WiFi 终结状态（不改动 importingFile —— 通道归调用方管）。
 * 用于 Socket 断开 / 出错 / BLE 断开 / 传输出错 / 人为中断等异常路径，避免宽限计时器在后台误触发回调。
 */
- (void)resetWifiTransferStateKeepMode {
    [self cancelWifiGraceTimer];
    self.wifiTransFinished = NO;
    self.wifiOffReceived = NO;
    self.wifiTailBuf = [NSMutableData dataWithCapacity:kWifiEndMarkerLen];
    self.wifiHoldBackBuf = [NSMutableData dataWithCapacity:kWifiHoldBackLen];
    self.fileLen = 0;
    self.socketByteLen = 0;
    self.wifiEmittedLen = 0;
    // 通告前缓冲随异常路径一并清空（Socket 断开等场景，避免残留到下一次传输）
    self.wifiPendingBuf = nil;
    self.wifiPendingChunks = nil;
    self.wifiPendingReplaying = NO;
}

#pragma mark - 设备信息指令解析

- (void)parseDeviceInfoCommand:(NSString *)resultInfo cmds:(NSArray<NSString *> *)cmds {
    if ([resultInfo hasPrefix:@"MCU&MAC&"]) {
        if (self.deviceInfoDelegate) {
            [self.deviceInfoDelegate onDeviceMac:cmds.count > 2 ? cmds[2] : @""];
        }
    } else if ([resultInfo hasPrefix:@"MCU&SPA&"]) {
        if (self.deviceInfoDelegate) {
            int remain = cmds.count > 2 ? [cmds[2] intValue] : 0;
            int capacity = cmds.count > 3 ? [cmds[3] intValue] : 0;
            [self.deviceInfoDelegate onDeviceCapacity:remain capacity:capacity];
        }
    }     else if ([resultInfo hasPrefix:@"MCU&FW&"]) {
        if (self.deviceInfoDelegate) {
            [self.deviceInfoDelegate onDeviceFirmwareVersion:cmds.count > 2 ? cmds[2] : @""];
        }
    } else if ([resultInfo hasPrefix:@"MCU&WF&"]) {
        // 杰理方案：WiFi 模块版本号（APP&WF → MCU&WF&1.0），对齐 FW 的解析方式
        if (self.deviceInfoDelegate && [self.deviceInfoDelegate respondsToSelector:@selector(onDeviceWifiVersion:)]) {
            [self.deviceInfoDelegate onDeviceWifiVersion:cmds.count > 2 ? cmds[2] : @""];
        }
    } else if ([resultInfo hasPrefix:@"MCU&USB&STA"]) {
        // 杰理方案 V1.1：Type-C USB 状态应答（APP&USB&STA → MCU&USB&STA&{1|0}）。
        // 与设备主动上报同前缀同解，cmds 切分后：
        //   cmds[0]="MCU"  cmds[1]="USB"  cmds[2]="STA"  cmds[3]={1|0}
        if (self.deviceInfoDelegate && [self.deviceInfoDelegate respondsToSelector:@selector(onUsbTransferStatus:)]) {
            int state = cmds.count > 3 ? [cmds[3] intValue] : 0;
            [self.deviceInfoDelegate onUsbTransferStatus:state];
        }
    } else if ([resultInfo hasPrefix:@"MCU&CT&"]) {
        // 杰理方案 V1.1：设备时间应答（APP&GT → MCU&CT&{yyyyMMddHHmmss}）。
        // cmds 切分后：cmds[0]="MCU"  cmds[1]="CT"  cmds[2]={时间字符串}
        if (self.deviceInfoDelegate && [self.deviceInfoDelegate respondsToSelector:@selector(onDeviceTime:)]) {
            [self.deviceInfoDelegate onDeviceTime:cmds.count > 2 ? cmds[2] : @""];
        }
    } else if ([resultInfo hasPrefix:@"MCU&BAT&"]) {
        // 杰理协议 V1.1 充电上报三种形态：
        //   MCU&BAT&RATE      普通应答/拔充电器（RATE=200 哨兵值表示充电中）
        //   MCU&BAT&RATE&C    插入充电器（C 后缀）
        //   MCU&BAT&100&F     充满（F 后缀）
        int level = cmds.count > 2 ? [cmds[2] intValue] : 0;
        JWDBatteryChargeStatus status = JWDBatteryChargeNone;
        if (cmds.count > 3) {
            NSString *suffix = cmds[3];
            if ([suffix isEqualToString:@"C"]) {
                status = JWDBatteryChargeCharging;
            } else if ([suffix isEqualToString:@"F"]) {
                status = JWDBatteryChargeFull;
            }
        } else if (level == 200) {
            // 无后缀但 RATE=200 哨兵值：充电中（协议约定）
            status = JWDBatteryChargeCharging;
        }
        if (self.batteryDelegate) {
            if ([self.batteryDelegate respondsToSelector:@selector(onBatteryChargeStatus:level:)]) {
                [self.batteryDelegate onBatteryChargeStatus:status level:level];
            }
            if ([self.batteryDelegate respondsToSelector:@selector(onBatteryLevel:)]) {
                [self.batteryDelegate onBatteryLevel:level];
            }
        }
    } else if ([resultInfo hasPrefix:@"MCU&FUNCTION&"]) {
        NSString *funcStrs = [resultInfo stringByReplacingOccurrencesOfString:@"MCU&FUNCTION&" withString:@""];
        self.supportSettings = [funcStrs componentsSeparatedByString:@"&"];
        if (self.settingDelegate) {
            [self.settingDelegate onSettingList:self.supportSettings];
        }
    } else if ([resultInfo hasPrefix:@"MCU&SET&"]) {
        if (!self.supportSettings || !self.settingDelegate) return;
        NSString *funcStatus = [resultInfo stringByReplacingOccurrencesOfString:@"MCU&SET&" withString:@""];
        NSArray<NSString *> *statusArr = [funcStatus componentsSeparatedByString:@"&"];
        NSMutableDictionary<NSString *, NSNumber *> *statusMap = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < statusArr.count && i < self.supportSettings.count; i++) {
            statusMap[self.supportSettings[i]] = @([statusArr[i] intValue]);
        }
        [self.settingDelegate onSettingStatus:statusMap];
    } else if (self.currentSettingName && [resultInfo hasPrefix:[NSString stringWithFormat:@"MCU&%@", self.currentSettingName]]) {
        if (self.settingDelegate) {
            [self.settingDelegate onSetSuccess:self.currentSettingName];
        }
    } else if ([resultInfo isEqualToString:@"MCU&T&OK"]) {
        if (self.settingDelegate) {
            [self.settingDelegate onTimeSyncSuccess];
        }
    }
}

#pragma mark - 音频数据处理

- (void)postAudioData:(NSData *)data {
    // 1. BK 标记文件通道：App 发起 APP&BK&{dir}/{fileName} 后，MCU 通过音频 notify 推送二进制 mark 内容
    //    必须优先于音频/文件下载分支判断，避免 mark 字节被误判为音频帧 / 文件数据
    if (self.isReceivingBk) {
        [self handleBkAudioData:data];
        return;
    }

    // 2. 原有的音频 / BLE 文件传输分支
    if (self.fileMgrDelegate && self.importingFile == 1) {
        // BLE文件传输模式，直接回调文件数据
        [self.fileMgrDelegate onFileData:data fileName:self.currentDownloadFile ?: @""];
    }
    
    if (self.recordStateDelegate && self.importingFile == 0) {
        // 录音模式：按设备型号路由 MP3 / Opus 解码器转 PCM 后回调。
        //
        // 2026-09-23 曾临时下线解码（音频流透传）用于测试；
        // 2026-09-28 恢复 SDK 内解码业务（恢复依据：docs/音频流与OPUS转换_恢复分析报告_v1.0.html）。
        //
        id<JWDAudioDecoder> decoder = self.activeAudioDecoder;
        if (decoder && decoder.isRunning) {
            [decoder decodeData:data];
            return;
        }
        [self.recordStateDelegate onRecordStream:data];
    }
}

#pragma mark - BK 标记文件状态机（对齐 Android ReplyParser）

/**
 * 缓存音频通道送来的标记文件字节流到 bkBuffer，不在此处触发 App 回调。
 * 完成时机由 MCU 通过 cmd 通道返回 MCU&BK&OK（兼容 APP&BK&OK）通知，
 * 届时由 finishFileBk 整体按 UTF-8 解码并按行解析为整数后回调 App。
 */
- (void)handleBkAudioData:(NSData *)data {
    if (!data || data.length == 0) {
        return;
    }
    [self.bkBuffer appendData:data];
}

/**
 * App 发送 APP&BK&{dir}/{fileName} 前调用：进入 BK 接收状态、清空缓存、通知 App 开始。
 * 由 JWDClient.getFileBk:fileName: 在发送协议前调用，确保 postAudioData 在协议往返窗口
 * 内到达的字节也能被正确路由到 bkBuffer（避免被录音 / BLE 文件下载分支误处理）。
 */
- (void)startFileBk:(NSString *)dir fileName:(NSString *)fileName {
    self.currentBkDir = dir;
    self.currentBkFile = fileName;
    self.bkBuffer.length = 0;
    self.isReceivingBk = YES;
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"请求获取标记文件: dir=%@, fileName=%@", dir, fileName]];
    if (self.fileBkDelegate && [self.fileBkDelegate respondsToSelector:@selector(onFileBkStart:fileName:)]) {
        [self.fileBkDelegate onFileBkStart:dir fileName:fileName];
    }
}

/**
 * 完成标记文件接收：把累积的字节按 UTF-8 解码、按行解析为整数集合，一次性回调 App。
 */
- (void)finishFileBk {
    if (!self.isReceivingBk) {
        [JWDSdkLogger w:TAG msg:@"未在 BK 接收状态, 忽略完成标记"];
        return;
    }
    self.isReceivingBk = NO;
    NSData *payload = [self.bkBuffer copy];
    self.bkBuffer.length = 0;
    NSString *dir = self.currentBkDir;
    NSString *fileName = self.currentBkFile;

    NSString *content = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding];
    if (!content) {
        // UTF-8 解码失败：按空内容处理，回调空 marks（不抛错，与 Android 行为一致由上层决定）
        [JWDSdkLogger w:TAG msg:@"标记文件 UTF-8 解码失败, 按空内容处理"];
        content = @"";
    }
    NSArray<NSNumber *> *marks = [self parseMarks:content];
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"标记文件接收完成: dir=%@, fileName=%@, size=%lu bytes",
                              dir, fileName, (unsigned long)payload.length]];
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"标记文件解析结果: 共 %lu 个整数: %@",
                              (unsigned long)marks.count, marks]];

    if (self.fileBkDelegate && [self.fileBkDelegate respondsToSelector:@selector(onFileBkReady:fileName:marks:)]) {
        [self.fileBkDelegate onFileBkReady:dir fileName:fileName marks:marks];
    }
}

/**
 * 标记文件接收失败：重置状态机并回调错误。
 * @param errorCode 0=通用错误, 1=非空闲状态, 2=该文件没有标记, 其他=未知
 * @param reason    失败原因描述
 */
- (void)finishFileBkWithError:(NSInteger)errorCode reason:(NSString *)reason {
    if (!self.isReceivingBk) {
        return;
    }
    self.isReceivingBk = NO;
    self.bkBuffer.length = 0;
    NSString *dir = self.currentBkDir;
    NSString *fileName = self.currentBkFile;
    [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"标记文件接收失败: code=%ld, reason=%@", (long)errorCode, reason]];
    if (self.fileBkDelegate && [self.fileBkDelegate respondsToSelector:@selector(onFileBkError:fileName:errorCode:reason:)]) {
        [self.fileBkDelegate onFileBkError:dir fileName:fileName errorCode:errorCode reason:reason];
    }
}

/**
 * 把标记文件文本按行解析为整数集合：
 * - 支持换行符 \r / \n / \r\n（跨平台）
 * - 每行 trim 后尝试整数解析，成功则加入列表
 * - 空行 / 解析失败的行跳过并打 warn 日志（不抛错）
 * - 全部行解析失败时返回空列表
 */
- (NSArray<NSNumber *> *)parseMarks:(NSString *)content {
    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    if (content.length == 0) {
        return result;
    }
    // 按 \r\n / \r / \n 切分（componentsSeparatedByString 顺序匹配 \r\n 优先）
    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\r\n"];
    for (NSString *segment in lines) {
        // 段内可能仍有 \r 或 \n 单独出现，再细分
        for (NSString *line in [segment componentsSeparatedByString:@"\r"]) {
            for (NSString *atomic in [line componentsSeparatedByString:@"\n"]) {
                NSString *trimmed = [atomic stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmed.length == 0) {
                    continue;
                }
                NSScanner *scanner = [NSScanner scannerWithString:trimmed];
                NSInteger value = 0;
                BOOL ok = [scanner scanInteger:&value] && scanner.isAtEnd;
                if (ok) {
                    [result addObject:@(value)];
                } else {
                    [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:@"标记文件行解析失败, 跳过: \"%@\"", trimmed]];
                }
            }
        }
    }
    return result;
}

#pragma mark - Socket管理

- (void)connectSocket {
    // 重置重试计数，开始新一轮连接
    self.socketRetryCount = 0;
    self.socketSessionActive = YES; // 标记加速会话开始，允许连接成功后断线自动重连
    [self attemptSocketConnect];
}

/**
 * 实际执行 Socket 连接（内部方法，支持重试）
 */
- (void)attemptSocketConnect {
    if (self.socketClient) {
        [self.socketClient destroy];
        self.socketClient = nil;
    }
    
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"Socket 连接中（第 %d 次）: %@:%d", self.socketRetryCount + 1, SOCKET_HOST, SOCKET_PORT]];
    self.socketClient = [[JWDSocketClient alloc] initWithHost:SOCKET_HOST port:SOCKET_PORT];
    self.socketClient.callback = self;
    [self.socketClient connect];
}

- (void)disconnectSocket {
    self.socketSessionActive = NO; // 标记会话结束，避免待执行的重连继续触发
    // WiFi 模式导入随 Socket 断开而结束
    // （异步 didDisconnected 回调会因 destroy 同步清除 callback 而丢失，必须在此处重置）
    // BLE 模式（1）不受影响
    if (self.importingFile == kWifiModeSocket) {
        self.importingFile = 0;
    }
    // Socket 主动断开：取消宽限计时器并复位终结状态，避免后台计时器事后误回调（边界场景 10）
    [self resetWifiTransferStateKeepMode];
    if (self.socketClient) {
        // 在断开前先通知 delegate（destroy 会清除 callback，异步 didDisconnected 将不会触发）
        // 仅当 socket 实际连接过时才通知，避免未连接时误触发
        if (self.socketClient.isConnected && self.socketStatusDelegate &&
            [self.socketStatusDelegate respondsToSelector:@selector(onSocketDisconnected:)]) {
            [self.socketStatusDelegate onSocketDisconnected:@"主动断开"];
        }
        [self.socketClient disconnect];
        [self.socketClient destroy];
        [JWDSdkLogger d:TAG msg:@"Socket手动断开"];
    }
    self.socketClient = nil;
}

- (void)closeWifiSession {
    [JWDSdkLogger i:TAG msg:@"关闭 WiFi 加速会话"];
    // 1. 断开 Socket（内部会设 socketSessionActive=NO，触发 onSocketDisconnected 回调重置 UI）
    [self disconnectSocket];
    // 2. 停止 WiFi 状态轮询
    [self stopWifiStatusQuery];
    // 3. 断开 iOS WiFi 热点连接（移除 NEHotspotConfiguration）
    [self.wifiConnector disconnectHotspot];
    // 4. 重置所有 WiFi 加速相关状态
    self.isWifiAccelerated = NO;
    self.isTargetWifiConnected = NO;
    self.isHotspotConnecting = NO;
    self.isWifiAccelerationUserInitiated = NO;
    self.isDeviceWifiActive = NO;
}

#pragma mark - JWDSocketClientCallback

- (void)socketClient:(JWDSocketClient *)client didConnect:(NSString *)host port:(int)port {
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"Socket connected to %@:%d (第%d次尝试成功)", host, port, self.socketRetryCount + 1]];
    self.socketRetryCount = 0;
    self.importingFile = 2;
    self.isWifiAccelerated = YES;
    self.socketSessionActive = YES;
    self.isWifiAccelerationUserInitiated = NO; // Socket 已连接，加速完成
    if (self.socketStatusDelegate) {
        [self.socketStatusDelegate onSocketConnected];
    }
}

- (void)socketClient:(JWDSocketClient *)client didConnectFailed:(NSString *)error {
    [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"Socket连接失败(第%d次): %@", self.socketRetryCount + 1, error]];
    
    // 容错重试机制：最多重试 MAX_SOCKET_RETRY 次
    if (self.socketRetryCount < MAX_SOCKET_RETRY) {
        self.socketRetryCount++;
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:@"准备第 %d/%d 次重试 Socket 连接...", self.socketRetryCount, MAX_SOCKET_RETRY]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SOCKET_RETRY_DELAY * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.socketSessionActive) {
                [JWDSdkLogger w:TAG msg:@"加速会话已结束，取消待执行的 Socket 重连"];
                return;
            }
            [self attemptSocketConnect];
        });
    } else {
        // 已达到最大重试次数，回调失败
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"Socket 连接失败，已重试 %d 次，放弃连接", MAX_SOCKET_RETRY]];
        self.socketRetryCount = 0;
        self.importingFile = 0;
        self.isWifiAccelerated = NO;
        self.socketSessionActive = NO;
        // 严格 apply/remove 配对（2026-10-10）：连接彻底失败也要移除热点配置，
        // 避免配置残留导致下次 apply 走 code=8 快速路径复用旧关联/旧 DHCP 租约
        self.isTargetWifiConnected = NO;
        [self.wifiConnector disconnectHotspot];
        if (self.socketStatusDelegate) {
            NSString *failMsg = [NSString stringWithFormat:@"Socket 连接失败（已重试 %d 次）: %@", MAX_SOCKET_RETRY, error];
            [self.socketStatusDelegate onSocketConnectFailed:failMsg];
        }
    }
}

- (void)socketClient:(JWDSocketClient *)client didReceiveData:(NSData *)data {
    JWDRunOnMainSerialized(^{
        [self handleWifiSocketData:data];
    });
}

/**
 * WiFi 数据通道每包到达的处理（对应 Android ReplyParser.onDataReceived）。
 *
 * 三条终结规则见需求文档第 4.2 节；对外统一输出事件码 1。
 */
- (void)handleWifiSocketData:(NSData *)data {
    if (!data || data.length == 0) return;
    if (!self.fileMgrDelegate) return;

    // 孤立结束符：非传输态下的 ≤5 字节包直接忽略（保留旧逻辑）
    if (data.length <= kWifiEndMarkerLen && self.importingFile == 0) return;

    // ★ 通告前缓冲（杰理时序，2026-10-09）：
    //   Socket 数据先于 BLE 的 MCU&U&len 到达时 fileLen 仍为 0。若直接进入下方
    //   「超长脏数据」防御（received >= fileLen+5），首包就会触发按 0 截断 →
    //   假"精确完成"事件 → 后续真实数据全部被当迟到数据丢弃（真机事故）。
    //   此处改为：WiFi 会话活跃 且 未见通告 且 非回放中 → 暂存等待通告回放。
    //   判定依据：importingFile 已随 Socket 连接置为 kWifiModeSocket（didConnect
    //   回调），而 fileLen 尚为 0 —— 即"通道就绪但预告未到"。
    if (self.fileLen == 0 && self.importingFile == kWifiModeSocket && !self.wifiPendingReplaying) {
        if (!self.wifiPendingBuf) {
            self.wifiPendingBuf = [NSMutableData data];
            self.wifiPendingChunks = [NSMutableArray array];
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                @"WiFi 数据先于 MCU&U&len 到达, 进入通告前缓冲 (首包 %lu 字节, file=%@)",
                (unsigned long)data.length, self.currentDownloadFile ?: @""]];
        }
        [self.wifiPendingBuf appendData:data];
        [(NSMutableArray *)self.wifiPendingChunks addObject:data];
        return;
    }

    // ★ 迟到数据守卫：本次传输已终结，直接丢弃，不透传、不二次回调（边界场景 7）
    if (self.wifiTransFinished) {
        [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:
                                 @"WiFi 文件传输已终结, 丢弃迟到数据 %lu 字节 (file=%@)",
                                 (unsigned long)data.length, self.currentDownloadFile ?: @""]];
        return;
    }

    self.socketByteLen += data.length;
    [self wifiAppendTail:data]; // tail5 滑动窗口，标记跨包也不漏检

    // ==== _P 设备（杰理）专用终结逻辑（2026-10-10 固件契约）====
    // 契约：MCU&OFF(&CRC32) 一定在 socket 字节全部发完之后经 BLE 到达，
    // 是文件传输完成的【唯一权威信号】。_P 流不带 5 字节结束标记，
    // 因此不再使用旧三规则提前终结：
    //   - 规则1（长度对齐即终结，不等 OFF）→ 禁用，长度对齐后继续等 OFF
    //   - 规则2（标记命中终结）→ _P 无标记，天然不触发
    //   - 超长脏数据截断 → 禁用，异常洪泛由会话断开路径兜底
    // 本路径仅两种走向：
    //   a) OFF 已到 且 数据已对齐 → 立即终结（事件 1 携带 OFF 里的 CRC32）
    //   b) 其余一律纯透传（含 OFF 未到 / 数据未对齐 / OFF 先到数据在途）
    //      —— OFF 先到时由 handleTransferOff 的对齐检查/宽限期统一收尾
    if ([self isJieliPDevice]) {
        if (self.wifiOffReceived && [self wifiIsExactlyAligned]) {
            [JWDSdkLogger i:TAG msg:@"_P 设备: OFF 已到达且数据对齐, 立即终结 (OFF 权威契约)"];
            [self wifiEmitFinalWithPacket:data stripMarker:[self wifiShouldStripMarker]];
            [self finishWifiTransferWithReason:JWDWifiFinishReasonExact];
            return;
        }
        [self wifiForwardStreamData:data];
        return;
    }

    BOOL markerTrusted = [self wifiMarkerIsTrustworthy];

    // ---- 规则1：数据自证（OFF 未到也终结）----
    if ([self wifiIsExactlyAligned]) {
        // 兼容路径 received==expected（无标记）→ 全量透传；received==expected+5 且命中标记 → 剥掉标记
        BOOL stripMarker = (self.socketByteLen == (long)(self.fileLen + kWifiEndMarkerLen));
        [self wifiEmitFinalWithPacket:data stripMarker:stripMarker];
        [self finishWifiTransferWithReason:JWDWifiFinishReasonExact];
        return;
    }

    // ---- OFF 已到达：宽限期内逐包重估 ----
    if (self.wifiOffReceived) {
        if (markerTrusted) {
            // 规则2：长度不足但标记命中 → 中途丢包
            [self wifiEmitFinalWithPacket:data stripMarker:YES];
            [self finishWifiTransferWithReason:JWDWifiFinishReasonLengthMismatch];
            return;
        }
        if (self.socketByteLen < self.fileLen) {
            // 在途数据继续落盘，保证应用层落盘与 SDK 计数口径一致（边界场景 15）
            [self wifiForwardStreamData:data];
            return;
        }
        // OFF 已到 + 长度已超预告但未精确对齐（fileLen < received < fileLen+5 的窗口）：
        // 标记还没到齐，交给宽限计时器到期统一裁定，本包按普通数据透传扣留
    }

    // ---- 异常防御：超长脏数据（超出预告+标记仍无标记命中）----
    if (self.socketByteLen >= (long)(self.fileLen + kWifiEndMarkerLen)) {
        [self wifiEmitTruncatedToExpectedLenWithPacket:data];
        [self finishWifiTransferWithReason:JWDWifiFinishReasonExact];
        return;
    }

    // ---- 普通数据 ----
    [self wifiForwardStreamData:data];
}

- (void)socketClient:(JWDSocketClient *)client didDisconnected:(NSString *)reason {
    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"Socket disconnected: %@", reason]];
    self.importingFile = 0;
    // 传输态随 Socket 断开一同复位：取消宽限计时器，防止事后触发一个假的完成事件
    [self resetWifiTransferStateKeepMode];
    if (self.socketStatusDelegate) {
        [self.socketStatusDelegate onSocketDisconnected:reason];
    }
    // 处于活跃加速会话中的异常断开（连接成功后设备踢连接等）→ 自动重连
    // 手动断开（disconnectSocket/reset）会先置 socketSessionActive=NO，不会走到这里触发重连
    if (self.socketSessionActive) {
        [self scheduleSocketReconnect:reason];
    } else {
        self.isWifiAccelerated = NO;
    }
}

/**
 * 断线重连（连接成功后的异常断开也走此逻辑，最多 MAX_SOCKET_RETRY 次）
 */
- (void)scheduleSocketReconnect:(NSString *)reason {
    if (self.socketRetryCount < MAX_SOCKET_RETRY) {
        self.socketRetryCount++;
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:@"Socket 断开，准备第 %d/%d 次重连...", self.socketRetryCount, MAX_SOCKET_RETRY]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SOCKET_RETRY_DELAY * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.socketSessionActive) {
                [JWDSdkLogger w:TAG msg:@"加速会话已结束，取消待执行的 Socket 重连"];
                return;
            }
            [self attemptSocketConnect];
        });
    } else {
        [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"Socket 重连失败，已重试 %d 次，放弃连接", MAX_SOCKET_RETRY]];
        self.socketRetryCount = 0;
        self.importingFile = 0;
        self.isWifiAccelerated = NO;
        self.socketSessionActive = NO;
        // 严格 apply/remove 配对（2026-10-10）：重连耗尽同样移除热点配置，
        // 避免残留配置让下次 apply 复用旧关联/旧 DHCP 租约
        self.isTargetWifiConnected = NO;
        [self.wifiConnector disconnectHotspot];
        if (self.socketStatusDelegate) {
            [self.socketStatusDelegate onSocketConnectFailed:[NSString stringWithFormat:@"Socket 连接失败（已重试 %d 次）: %@", MAX_SOCKET_RETRY, reason]];
        }
    }
}

- (void)socketClient:(JWDSocketClient *)client didError:(NSString *)error {
    [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"Socket error: %@", error]];
    self.importingFile = 0;
    // Socket 出错：同上，取消宽限计时器并复位终结状态（边界场景 10）
    [self resetWifiTransferStateKeepMode];
    if (self.socketStatusDelegate) {
        NSException *exception = [NSException exceptionWithName:@"SocketError" reason:error userInfo:nil];
        [self.socketStatusDelegate onSocketError:error exception:exception];
    }
}

#pragma mark - WiFi 状态轮询

- (void)startWifiStatusQuery {
    [self stopWifiStatusQuery];
    self.wifiStatusQueryCount = 0;
    
    [JWDSdkLogger i:TAG msg:@"开始 WiFi 状态轮询"];
    
    self.wifiStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                           target:self
                                                         selector:@selector(wifiStatusTimerFired:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)stopWifiStatusQuery {
    [self.wifiStatusTimer invalidate];
    self.wifiStatusTimer = nil;
    self.wifiStatusQueryCount = 0;
}

- (void)wifiStatusTimerFired:(NSTimer *)timer {
    self.wifiStatusQueryCount++;
    
    // 最多轮询 30 次（30秒），超时后停止
    if (self.wifiStatusQueryCount > 30) {
        [JWDSdkLogger w:TAG msg:@"WiFi 状态轮询超时，停止轮询"];
        [self stopWifiStatusQuery];
        return;
    }
    
    // 发送 WiFi 状态查询命令
    if (self.sendCommandBlock) {
        self.sendCommandBlock(@"APP&WIFIS");
    }
}

#pragma mark - 生命周期

- (void)reset {
    [self closeWifiSession];
    // 2026-09-23：解码器不再启动，理论上无需 stop；保留调用作防御（stop 对未启动的解码器是安全空操作）
    [self.mp3Decoder stop];
    [self.opusDecoder stop];
    self.isAuth = NO;
    self.importingFile = 0;
    // BLE 断开（全局 reset）：复位全部 WiFi 传输状态与宽限计时器（边界场景 11）
    [self resetWifiTransferStateKeepMode];
    // 重置 BK 标记文件接收状态机：蓝牙断开时不再继续缓存，避免下次连接后状态错乱
    self.isReceivingBk = NO;
    self.bkBuffer.length = 0;
    self.currentBkDir = nil;
    self.currentBkFile = nil;
}

- (void)releaseResources {
    [self closeWifiSession];
    // 同上：防御性 stop（空操作）
    [self.mp3Decoder stop];
    [self.opusDecoder stop];
    self.isAuth = NO;
}

- (void)stopWifiStatusTimer {
    [self stopWifiStatusQuery];
}

- (void)dealloc {
    [self releaseResources];
}

#pragma mark - 音频解码器路由

- (void)configureWithAudioDecoderType:(JWDAudioDecoderType)type {
    if (type == self.currentAudioDecoderType) {
        return;
    }

    JWDAudioDecoderType oldType = self.currentAudioDecoderType;
    id<JWDAudioDecoder> oldDecoder = self.activeAudioDecoder;
    id<JWDAudioDecoder> newDecoder = nil;

    switch (type) {
        case JWDAudioDecoderTypeOpus:
            newDecoder = self.opusDecoder;
            break;
        case JWDAudioDecoderTypeMP3:
        default:
            newDecoder = self.mp3Decoder;
            break;
    }

    // 若旧解码器正在录音，先 stop 释放 libopus decoder / AudioConverter
    if (oldDecoder && oldDecoder.isRunning) {
        [oldDecoder stop];
    }

    self.activeAudioDecoder = newDecoder;
    self.currentAudioDecoderType = type;

    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
        @"切换音频解码器: %@ → %@ (设备型号判定)",
        oldType == JWDAudioDecoderTypeOpus ? @"Opus" : @"MP3",
        type == JWDAudioDecoderTypeOpus ? @"Opus" : @"MP3"]];
}

@end
