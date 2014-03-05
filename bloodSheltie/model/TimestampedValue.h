#import <Foundation/Foundation.h>
#import <Mantle/MTLModel.h>
#import <Mantle/MTLJSONAdapter.h>

@interface TimestampedValue : MTLModel <MTLJSONSerializing>
@property (readonly) NSDate *internalTime;
@property (readonly) NSDate *userTime;
@property (readonly) NSTimeZone *timezone;

- (instancetype)initWithInternalTime:(NSDate *)internalTime userTime:(NSDate *)userTime timezone:(NSTimeZone *)timezone;

- (NSString *)description;

+ (instancetype)valueWithInternalTime:(NSDate *)internalTime userTime:(NSDate *)userTime timezone:(NSTimeZone *)timezone;


@end