//
//  JWDSocketClient.h
//  JwdVtrSDK
//
//  JWD VTR SDK - TCP Socket 客户端
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class JWDSocketClient;

@protocol JWDSocketClientCallback <NSObject>
- (void)socketClient:(JWDSocketClient *)client didConnect:(NSString *)host port:(int)port;
- (void)socketClient:(JWDSocketClient *)client didConnectFailed:(NSString *)error;
- (void)socketClient:(JWDSocketClient *)client didReceiveData:(NSData *)data;
- (void)socketClient:(JWDSocketClient *)client didDisconnected:(NSString *)reason;
- (void)socketClient:(JWDSocketClient *)client didError:(NSString *)error;
@end

@interface JWDSocketClient : NSObject

@property (nonatomic, weak, nullable) id<JWDSocketClientCallback> callback;
@property (nonatomic, assign, readonly) BOOL isConnected;
@property (nonatomic, assign, readonly) BOOL isConnecting;

- (instancetype)initWithHost:(NSString *)host port:(int)port;
- (void)connect;
- (void)disconnect;
- (void)destroy;

@end

NS_ASSUME_NONNULL_END
