//
//  JWDRecordState.m
//  JwdVtrSDK
//

#import "JWDRecordState.h"

NSString * JWDRecordStateDescription(JWDRecordState state) {
    switch (state) {
        case JWDRecordStateStorageFull:    return @"存储已满";
        case JWDRecordStateNormalError:    return @"录音错误";
        case JWDRecordStateStopped:        return @"停止录音";
        case JWDRecordStateNormalRecording: return @"开始普通录音";
        case JWDRecordStatePhoneRecording: return @"开始电话录音";
        case JWDRecordStateNormalRecorded: return @"普通录音中";
        case JWDRecordStatePhoneRecorded:  return @"电话录音中";
        default:                           return @"未知状态";
    }
}
