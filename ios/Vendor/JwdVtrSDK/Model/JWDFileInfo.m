//
//  JWDFileInfo.m
//  JwdVtrSDK
//

#import "JWDFileInfo.h"

@implementation JWDFileInfo

- (instancetype)initWithFileName:(NSString *)fileName duration:(long)duration {
    self = [super init];
    if (self) {
        _fileName = [fileName copy];
        _duration = duration;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"JWDFileInfo{fileName='%@', duration=%ld}", self.fileName, (long)self.duration];
}

@end
