//
//  JWDSocketClient.m
//  JwdVtrSDK
//

#import "JWDSocketClient.h"
#import "JWDSdkLogger.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <ifaddrs.h>
#if TARGET_OS_IPHONE
#import <SystemConfiguration/CaptiveNetwork.h>
#endif

static NSString *const TAG = @"JWDSocketClient";
static const NSTimeInterval CONNECT_TIMEOUT = 2.0; // 连接超时: 2秒

/// 把 NSError 完整展开成 domain/code/underlying 链（POSIX 错误码是定位关键：
/// 57=ENOTCONN 54=ECONNRESET 50=ENETDOWN 65=EHOSTUNREACH，各自指向不同根因）
static NSString *JWDDescribeStreamError(NSError *error) {
    if (!error) return @"(nil)";
    NSMutableString *desc = [NSMutableString stringWithFormat:@"%@/code=%ld",
                             error.domain, (long)error.code];
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    NSInteger depth = 0;
    while (underlying && depth < 3) {
        [desc appendFormat:@" → underlying %@/code=%ld",
         underlying.domain, (long)underlying.code];
        underlying = underlying.userInfo[NSUnderlyingErrorKey];
        depth++;
    }
    return desc;
}

/// 查询当前是否仍持有设备热点的 IPv4 地址（192.168.200.x）。
/// 流错误/连接失败瞬间调用：接口地址仍在 → 手机没掉热点，是设备端行为；
/// 接口地址消失 → iOS 已脱离热点（关联被撤），属于本地网络层问题。
static NSString *JWDCurrentHotspotInterfaces(void) {
    struct ifaddrs *ifap = NULL;
    if (getifaddrs(&ifap) != 0) return @"(getifaddrs 失败)";
    NSMutableArray *found = [NSMutableArray array];
    for (struct ifaddrs *ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL || ifa->ifa_addr->sa_family != AF_INET) continue;
        char addrBuf[INET_ADDRSTRLEN] = {0};
        const char *addr = inet_ntop(AF_INET,
                                     &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr,
                                     addrBuf, sizeof(addrBuf));
        if (addr && strncmp(addr, "192.168.200.", 12) == 0) {
            [found addObject:[NSString stringWithFormat:@"%s=%s", ifa->ifa_name, addr]];
        }
    }
    freeifaddrs(ifap);
    return found.count > 0
        ? [found componentsJoinedByString:@", "]
        : @"(无 192.168.200.x 接口地址 — 手机已不在设备热点)";
}

/// 查询 iOS 当前关联的 Wi-Fi SSID（CNCopyCurrentNetworkInfo）。
/// 用于错误瞬间的网络归属判定：SSID 仍是设备热点 → 手机没走（设备端行为）；
/// SSID 变成别的/为空 → iOS 漫游/掉线（本地行为）。
/// 注：需在 App 具备本地网络/定位相关权限时才有效，取不到返回 "(SSID 不可得)"。
/// macOS（测试台编译）：CNCopyCurrentNetworkInfo 不可用，直接返回占位（不影响其余诊断）。
#if TARGET_OS_IPHONE
static NSString *JWDCurrentWifiSSID(void) {
    NSString *ssid = nil;
    NSArray *interfaces = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    for (NSString *iface in interfaces) {
        CFDictionaryRef info = CNCopyCurrentNetworkInfo((__bridge CFStringRef)iface);
        if (info) {
            CFStringRef s = CFDictionaryGetValue(info, kCNNetworkInfoKeySSID);
            if (s) {
                ssid = (__bridge_transfer NSString *)CFStringCreateCopy(kCFAllocatorDefault, s);
            }
            CFRelease(info);
            if (ssid) break;
        }
    }
    return ssid ?: @"(SSID 不可得)";
}
#else
static NSString *JWDCurrentWifiSSID(void) { return @"(macOS 无 SSID API)"; }
#endif

@interface JWDSocketClient () <NSStreamDelegate>
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) int port;
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, assign, readwrite) BOOL isConnecting;
@property (nonatomic, strong, nullable) NSInputStream *inputStream;
@property (nonatomic, strong, nullable) NSOutputStream *outputStream;
@property (nonatomic, strong, nullable) NSThread *readThread;
@property (nonatomic, assign) CFRunLoopRef socketRunLoop; // 后台线程的RunLoop引用
@property (nonatomic, assign) BOOL isTimedOut; // 连接是否超时
// === 2026-10-09 诊断增强：连接成功时刻的基线快照 ===
// 用于 Stream error 时计算「距连接成功多久」——亚秒级指向设备端踢连接，
// 几十秒级指向 iOS 漫游/后台断网；SSID 前后对比直接区分"谁踢了谁"。
@property (nonatomic, assign) CFAbsoluteTime connectedAt;      // 连接成功时刻（CFAbsoluteTime）
@property (nonatomic, copy, nullable) NSString *connectedSSID;  // 连接成功时的 SSID
// === 2026-10-10 诊断增强：本连接累计接收字节数（对照 MCU&U&len 判断进度/丢包）===
@property (nonatomic, assign) NSUInteger totalBytesReceived;
@end

@implementation JWDSocketClient

- (instancetype)initWithHost:(NSString *)host port:(int)port {
    self = [super init];
    if (self) {
        _host = [host copy];
        _port = port;
        _isConnected = NO;
        _isConnecting = NO;
        _socketRunLoop = NULL;
    }
    return self;
}

- (void)connect {
    if (self.isConnected) {
        [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:@"Already connected to %@:%d", self.host, self.port]];
        return;
    }
    if (self.isConnecting) {
        [JWDSdkLogger w:TAG msg:@"Connection in progress"];
        return;
    }
    self.isConnecting = YES;
    self.isTimedOut = NO;
    
    // 启动连接超时定时器（2秒）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(CONNECT_TIMEOUT * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.isConnecting && !self.isConnected) {
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:@"Socket 连接超时（%.0fs），%@:%d", CONNECT_TIMEOUT, self.host, self.port]];
            self.isTimedOut = YES;
            self.isConnecting = NO;
            [self closeStreams];
            // 停止后台线程的RunLoop
            if (self.socketRunLoop) {
                CFRunLoopStop(self.socketRunLoop);
                self.socketRunLoop = NULL;
            }
            NSString *timeoutMsg = [NSString stringWithFormat:@"连接超时（%.0fs）", CONNECT_TIMEOUT];
            if ([self.callback respondsToSelector:@selector(socketClient:didConnectFailed:)]) {
                [self.callback socketClient:self didConnectFailed:timeoutMsg];
            }
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            [self doConnect];
        }
    });
}

- (void)doConnect {
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       (__bridge CFStringRef)self.host,
                                       (UInt32)self.port,
                                       &readStream,
                                       &writeStream);
    
    if (readStream && writeStream) {
        self.inputStream = (__bridge_transfer NSInputStream *)readStream;
        self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        
        // 设置TLS/SSL为不启用（设备端不需要SSL）
        [self.inputStream setProperty:NSStreamSocketSecurityLevelNone
                               forKey:NSStreamSocketSecurityLevelKey];
        [self.outputStream setProperty:NSStreamSocketSecurityLevelNone
                                forKey:NSStreamSocketSecurityLevelKey];
        
        self.inputStream.delegate = self;
        self.outputStream.delegate = self;
        
        // 保存当前后台线程的RunLoop引用，供断开连接时使用
        self.socketRunLoop = CFRunLoopGetCurrent();
        
        // 在RunLoop中调度
        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.inputStream open];
        [self.outputStream open];
        
        // 保持RunLoop运行
        CFRunLoopRun();
    } else {
        self.isConnecting = NO;
        NSString *error = @"Failed to create socket streams";
        [JWDSdkLogger e:TAG msg:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.callback respondsToSelector:@selector(socketClient:didConnectFailed:)]) {
                [self.callback socketClient:self didConnectFailed:error];
            }
        });
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            if (aStream == self.inputStream) {
                // 如果已经超时，忽略此事件（超时定时器已回调失败）
                if (self.isTimedOut) {
                    [JWDSdkLogger w:TAG msg:@"Stream opened but already timed out, ignoring"];
                    break;
                }
                self.isConnected = YES;
                self.isConnecting = NO;
                self.totalBytesReceived = 0; // 新连接从零计数
                // 诊断基线：记录连接成功时刻 + 当时关联的 SSID / 热点接口
                self.connectedAt = CFAbsoluteTimeGetCurrent();
                self.connectedSSID = JWDCurrentWifiSSID();
                [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:
                    @"Connected to %@:%d (连接成功基线: SSID=%@, 热点接口=%@)",
                    self.host, self.port, self.connectedSSID, JWDCurrentHotspotInterfaces()]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.callback respondsToSelector:@selector(socketClient:didConnect:port:)]) {
                        [self.callback socketClient:self didConnect:self.host port:self.port];
                    }
                });
            }
            break;
            
        case NSStreamEventHasBytesAvailable:
            if (aStream == self.inputStream) {
                uint8_t buffer[1024];
                NSInteger bytesRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
                if (bytesRead > 0) {
                    NSData *data = [NSData dataWithBytes:buffer length:(NSUInteger)bytesRead];
                    // 累计本连接已接收的总字节数（诊断用：对照 MCU&U&len 预告长度判断进度/丢包）
                    self.totalBytesReceived += (NSUInteger)bytesRead;
                    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"Received %ld bytes (累计 %lu bytes)",
                                              (long)bytesRead, (unsigned long)self.totalBytesReceived]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.callback respondsToSelector:@selector(socketClient:didReceiveData:)]) {
                            [self.callback socketClient:self didReceiveData:data];
                        }
                    });
                }
            }
            break;
            
        case NSStreamEventErrorOccurred: {
            // 如果已经超时，忽略此事件
            if (self.isTimedOut) {
                [JWDSdkLogger w:TAG msg:@"Stream error but already timed out, ignoring"];
                break;
            }
            NSError *error = aStream.streamError;
            // 2026-10-09 诊断增强：连接成功后随即断开的真机偶发问题。
            // 证据一（10-08）：流方向 / 完整错误码链 / 热点接口快照。
            // 证据二（10-09）：距连接成功的毫秒差（亚秒→设备踢；几十秒→iOS 漫游/后台）
            //              + SSID 前后对比（iOS 认为自己现在在哪个网络）。
            NSString *elapsed;
            if (self.isConnected && self.connectedAt > 0) {
                NSInteger ms = (NSInteger)((CFAbsoluteTimeGetCurrent() - self.connectedAt) * 1000.0);
                elapsed = [NSString stringWithFormat:@"%ldms", (long)ms];
            } else {
                elapsed = @"(连接未成功)";
            }
            [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:
                @"Stream error 诊断: 流=%@, 错误=%@, 状态: isConnected=%@ isConnecting=%@, 热点接口=%@, 距连接成功=%@, SSID: %@ → %@",
                (aStream == self.inputStream) ? @"input(读)" : @"output(写)",
                JWDDescribeStreamError(error),
                self.isConnected ? @"YES" : @"NO",
                self.isConnecting ? @"YES" : @"NO",
                JWDCurrentHotspotInterfaces(),
                elapsed,
                self.connectedSSID ?: @"(未记录)",
                JWDCurrentWifiSSID()]];
            NSString *errorMsg = [NSString stringWithFormat:@"Stream error: %@", error.localizedDescription];

            if (!self.isConnected && self.isConnecting) {
                // 连接阶段失败：关闭流 + 停止 RunLoop，防止幽灵事件
                self.isConnecting = NO;
                [self closeStreams];
                if (self.socketRunLoop) {
                    CFRunLoopStop(self.socketRunLoop);
                    self.socketRunLoop = NULL;
                }
                // 连接失败同样记录接口状态（ENETDOWN 时能看到热点地址已消失）
                [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:
                    @"连接失败诊断: 错误=%@, 热点接口=%@",
                    JWDDescribeStreamError(error), JWDCurrentHotspotInterfaces()]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.callback respondsToSelector:@selector(socketClient:didConnectFailed:)]) {
                        [self.callback socketClient:self didConnectFailed:errorMsg];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.callback respondsToSelector:@selector(socketClient:didError:)]) {
                        [self.callback socketClient:self didError:errorMsg];
                    }
                });
                [self disconnectWithReason:errorMsg];
            }
            break;
        }
            
        case NSStreamEventEndEncountered:
            [self disconnectWithReason:@"Server closed connection"];
            break;
            
        default:
            break;
    }
}

- (void)disconnect {
    [self disconnectWithReason:@"Manual disconnect"];
}

- (void)disconnectWithReason:(NSString *)reason {
    if (!self.isConnected && !self.isConnecting && !self.isTimedOut) return;
    
    [JWDSdkLogger d:TAG msg:[NSString stringWithFormat:@"Disconnecting: %@", reason]];
    
    self.isConnected = NO;
    self.isConnecting = NO;
    
    [self closeStreams];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.callback respondsToSelector:@selector(socketClient:didDisconnected:)]) {
            [self.callback socketClient:self didDisconnected:reason];
        }
    });
    
    // 停止后台线程的RunLoop（使用保存的引用，确保停止正确的RunLoop）
    if (self.socketRunLoop) {
        CFRunLoopStop(self.socketRunLoop);
        self.socketRunLoop = NULL;
    }
}

- (void)closeStreams {
    // 注意：此处直接从任意线程关闭流，close方法会自动处理RunLoop清理
    // RunLoop将在disconnectWithReason中通过保存的引用停止
    if (self.inputStream) {
        [self.inputStream close];
        self.inputStream = nil;
    }
    if (self.outputStream) {
        [self.outputStream close];
        self.outputStream = nil;
    }
}

- (void)destroy {
    [JWDSdkLogger d:TAG msg:@"Destroying SocketClient"];
    // 强制清理，不依赖 disconnectWithReason 的状态检查
    self.isConnected = NO;
    self.isConnecting = NO;
    [self closeStreams];
    if (self.socketRunLoop) {
        CFRunLoopStop(self.socketRunLoop);
        self.socketRunLoop = NULL;
    }
    self.callback = nil;
}

- (void)dealloc {
    [self closeStreams];
}

@end
