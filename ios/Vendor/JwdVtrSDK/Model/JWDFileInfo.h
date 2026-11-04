//
//  JWDFileInfo.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 文件信息实体
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JWDFileInfo : NSObject

/** 文件名称 */
@property (nonatomic, copy) NSString *fileName;

/** 文件时长（秒） */
@property (nonatomic, assign) long duration;

- (instancetype)initWithFileName:(NSString *)fileName duration:(long)duration;

@end

NS_ASSUME_NONNULL_END
