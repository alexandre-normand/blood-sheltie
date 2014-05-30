#import <Foundation/Foundation.h>
#import "TimestampedValue.h"
#import "ModelTypes.h"

@interface MeterRead : TimestampedValue
@property(readonly) NSDate *meterTime;
@property(readonly) float meterRead;
@property(readonly) GlucoseMeasurementUnit glucoseMeasurementUnit;

- (instancetype)initWithInternalTime:(NSDate *)internalTime userTime:(NSDate *)userTime timezone:(NSTimeZone *)userTimezone meterTime:(NSDate *)meterTime meterRead:(float)meterRead glucoseMeasurementUnit:(GlucoseMeasurementUnit)glucoseMeasurementUnit;

- (NSString *)description;

+ (instancetype)valueWithInternalTime:(NSDate *)internalTime userTime:(NSDate *)userTime timezone:(NSTimeZone *)userTimezone meterTime:(NSDate *)meterTime meterRead:(float)meterRead glucoseMeasurementUnit:(GlucoseMeasurementUnit)glucoseMeasurementUnit;

@end