#import <Foundation/Foundation.h>
#import "ORSSerialPort.h"

@class SyncData;


@interface SyncEvent : NSObject
@property(readonly) ORSSerialPort *port;
@property(readonly) SyncData *sessionData;

- (instancetype)initWithPort:(ORSSerialPort *)port sessionData:(SyncData *)sessionData;

+ (instancetype)eventWithPort:(ORSSerialPort *)port sessionData:(SyncData *)sessionData;

@end