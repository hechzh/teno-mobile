//
//  JWDWifiConnector.m
//  JwdVtrSDK
//
//  JWD VTR SDK - WiFi 热点连接工具实现
//  对标 Android WifiConnectUtil.connectToHotspot()
//

#import "JWDWifiConnector.h"
#import "JWDSdkLogger.h"
#import <NetworkExtension/NetworkExtension.h>

static NSString *const TAG = @"JWDWifiConnector";

@interface JWDWifiConnector ()
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, copy, nullable) NSString *currentSSID;
@property (nonatomic, assign) BOOL isCancelled; // 连接过程中被取消（设备 WiFi 已关闭）
@end

@implementation JWDWifiConnector

- (void)connectToHotspotWithSSID:(NSString *)ssid
                        password:(NSString *)password
                      completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (ssid.length == 0 || password.length == 0) {
        [JWDSdkLogger e:TAG msg:@"SSID 或密码不能为空"];
        if (completion) completion(NO, @"SSID or password can't be null");
        return;
    }
    
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"开始连接 WiFi 热点: SSID=%@", ssid]];

    // 2026-10-09 排查转圈问题：显式打印 applyConfiguration 的实际调用（含序号），
    // 用于从日志确认"整个加速会话只 apply 一次"（幂等守卫是否生效的直接证据）。
    // 每次会话从 connectToHotspotWithSSID 进入即计数，重复出现同序号以外的行
    // = 存在未被守卫的调用路径。
    static NSInteger applyCount = 0;
    applyCount++;
    const NSInteger thisApply = applyCount;
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"[APPLY#%ld] applyConfiguration 提交系统: SSID=%@ (joinOnce=YES)",
                              (long)thisApply, ssid]];

    // 2026-10-10 严格 apply/remove 配对：apply 前先移除同 SSID 的残留配置（若有）。
    // 若上次会话异常残留配置（App 被杀 / socket 放弃后未清理），本次 apply 会命中
    // code=8/13 走"已连接"快速路径 —— 关联快速恢复 + 复用旧 DHCP 租约。
    // 先 remove 强制每次都走全新的 关联 + DHCP discover 流程，排除旧租约导致的
    // IP 怪异状态。注：不走 disconnectHotspot（其 isCancelled 会取消随后的 apply），
    // 直接调 removeConfigurationForSSID（无残留时为幂等空操作）。
    [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"[REMOVE] apply 前清理残留配置: SSID=%@（确保全新关联+DHCP discover）", ssid]];
    [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];

    // 重置取消标志
    self.isCancelled = NO;
    self.currentSSID = ssid; // 先记录 SSID，供 disconnectHotspot 使用
    
    // 使用 NEHotspotConfiguration（iOS 11+），这是 iOS 连接 WiFi 热点的标准方式
    // 对标 Android 的 WifiNetworkSpecifier + ConnectivityManager.requestNetwork()
    NEHotspotConfiguration *config = [[NEHotspotConfiguration alloc] initWithSSID:ssid
                                                                         passphrase:password
                                                                            isWEP:NO];
    // joinOnce=YES: 仅在当前会话期间保持连接，App 退出后自动断开
    // 这比持久化配置更安全，且不会污染用户的 WiFi 列表
    config.joinOnce = YES;
    
    [[NEHotspotConfigurationManager sharedManager] applyConfiguration:config
                                                   completionHandler:^(NSError * _Nullable error) {
        // 检查是否在等待用户确认期间已被取消（设备 WiFi 已关闭）
        if (self.isCancelled) {
            [JWDSdkLogger w:TAG msg:[NSString stringWithFormat:
                @"[APPLY#%ld] WiFi 热点连接已被取消（设备 WiFi 已关闭），忽略 completion 回调", (long)thisApply]];
            self.isConnected = NO;
            // 即使 iOS 报告成功也视为失败
            if (completion) completion(NO, @"设备 WiFi 已关闭");
            return;
        }

        if (!error) {
            [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"WiFi 热点连接成功: %@ [APPLY#%ld]",
                                      ssid, (long)thisApply]];
            self.isConnected = YES;
            self.currentSSID = ssid;
            if (completion) completion(YES, nil);
        } else {
            // error.code == 7: 用户取消了连接（点击「不加入」）
            // error.code == 8: 已经连接到该热点
            // error.code == 13: 热点配置已存在
            if (error.code == 8) {
                [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"WiFi 已连接: %@ [APPLY#%ld, code=8 视为成功]",
                                          ssid, (long)thisApply]];
                self.isConnected = YES;
                self.currentSSID = ssid;
                if (completion) completion(YES, nil);
            } else if (error.code == 7) {
                [JWDSdkLogger w:TAG msg:@"用户取消了 WiFi 连接"];
                self.isConnected = NO;
                if (completion) completion(NO, @"用户取消了连接");
            } else {
                [JWDSdkLogger e:TAG msg:[NSString stringWithFormat:@"WiFi 连接失败: %@", error.localizedDescription]];
                self.isConnected = NO;
                if (completion) completion(NO, error.localizedDescription);
            }
        }
    }];
}

- (void)disconnectHotspot {
    // 设置取消标志，使正在进行的 applyConfiguration completion 回调失效
    self.isCancelled = YES;
    if (self.currentSSID) {
        [JWDSdkLogger i:TAG msg:[NSString stringWithFormat:@"移除 WiFi 热点配置: %@", self.currentSSID]];
        [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:self.currentSSID];
    }
    self.isConnected = NO;
    self.currentSSID = nil;
}

@end
