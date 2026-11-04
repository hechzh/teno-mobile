//
//  JWDWifiInfo.h
//  JwdVtrSDK
//
//  JWD VTR SDK - WiFi信息实体
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JWDWifiInfo : NSObject

/** WiFi 名称 */
@property (nonatomic, copy) NSString *ssid;

/** WiFi 密码 */
@property (nonatomic, copy) NSString *password;

@end

NS_ASSUME_NONNULL_END
