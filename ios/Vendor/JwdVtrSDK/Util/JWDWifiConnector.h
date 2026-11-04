//
//  JWDWifiConnector.h
//  JwdVtrSDK
//
//  JWD VTR SDK - WiFi 热点连接工具
//  对标 Android WifiConnectUtil，使用 NEHotspotConfiguration 连接设备热点
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * WiFi 热点连接工具（iOS 最佳实践）
 *
 * 使用 NetworkExtension 的 NEHotspotConfiguration API 将 iPhone 连接到设备 WiFi 热点。
 * 系统会弹出确认对话框，用户确认后自动连接。
 *
 * 注意：需要在 App Target 的 entitlements 中添加:
 * com.apple.developer.networking.HotspotConfiguration = YES
 */
@interface JWDWifiConnector : NSObject

@property (nonatomic, assign, readonly) BOOL isConnected;

/**
 * 连接到 WiFi 热点
 * iOS 系统会弹出确认对话框，用户点击「加入」后连接
 * @param ssid     WiFi 名称
 * @param password WiFi 密码
 * @param completion 连接结果回调（在主线程执行）
 */
- (void)connectToHotspotWithSSID:(NSString *)ssid
                        password:(NSString *)password
                      completion:(void (^)(BOOL success, NSString * _Nullable error))completion;

/**
 * 断开并移除已保存的热点配置
 * 调用后系统会自动恢复到之前的 WiFi 网络
 */
- (void)disconnectHotspot;

@end

NS_ASSUME_NONNULL_END
