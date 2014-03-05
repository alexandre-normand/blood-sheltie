#import <Foundation/Foundation.h>
#import "TimestampedEvent.h"


@interface HealthEvent : TimestampedEvent
@property(readonly) NSString *type;
@property(readonly) NSString *details;

- (instancetype)initWithInternalTime:(NSDate *)internalTime userTime:(NSDate *)userTime userTimezone:(NSTimeZone *)userTimezone eventTime:(NSDate *)eventTime type:(NSString *)type details:(NSString *)details;

+ (instancetype)valueWithInternalTime:(NSDate *)internalTime userTime:(NSDate *)userTime userTimezone:(NSTimeZone *)userTimezone eventTime:(NSDate *)eventTime type:(NSString *)type details:(NSString *)details;

- (NSString *)description;
@end