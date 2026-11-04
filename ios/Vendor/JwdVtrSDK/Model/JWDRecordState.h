//
//  JWDRecordState.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 录音状态枚举
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 录音状态枚举
 */
typedef NS_ENUM(NSInteger, JWDRecordState) {
    JWDRecordStateStorageFull    = -2,  // 存储已满
    JWDRecordStateNormalError    = -1,  // 录音错误
    JWDRecordStateStopped        = 0,   // 停止录音
    JWDRecordStateNormalRecording = 1,  // 开始普通录音
    JWDRecordStatePhoneRecording = 2,   // 开始电话录音
    JWDRecordStateNormalRecorded = 3,   // 普通录音中（设备主动上报）
    JWDRecordStatePhoneRecorded  = 4,   // 电话录音中（设备主动上报）
};

/**
 * 根据 code 获取录音状态描述
 */
NSString * JWDRecordStateDescription(JWDRecordState state);

NS_ASSUME_NONNULL_END
