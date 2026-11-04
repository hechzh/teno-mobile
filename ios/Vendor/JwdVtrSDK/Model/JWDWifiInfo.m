//
//  JWDWifiInfo.m
//  JwdVtrSDK
//

#import "JWDWifiInfo.h"

@implementation JWDWifiInfo

- (NSString *)description {
    return [NSString stringWithFormat:@"JWDWifiInfo{ssid='%@', password='%@'}", self.ssid, self.password];
}

@end
