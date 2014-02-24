#import <Foundation/Foundation.h>
#import <Mantle/MTLJSONAdapter.h>

@class RecordSyncTag;


@interface SyncTag : MTLModel <MTLJSONSerializing>
@property (nonatomic, copy, readonly) NSString *serialNumber;
@property (nonatomic, copy, readonly) RecordSyncTag *lastCalibrationRead;
@property (nonatomic, copy, readonly) RecordSyncTag *lastUserEvent;
@property (nonatomic, copy, readonly) RecordSyncTag *lastGlucoseRead;

- (instancetype)initWithSerialNumber:(NSString *)serialNumber lastGlucoseRead:(RecordSyncTag *)lastGlucoseRead lastUserEvent:(RecordSyncTag *)lastUserEvent lastCalibrationRead:(RecordSyncTag *)lastCalibrationRead;

+ (instancetype)tagWithSerialNumber:(NSString *)serialNumber lastGlucoseRead:(RecordSyncTag *)lastGlucoseRead lastUserEvent:(RecordSyncTag *)lastUserEvent lastCalibrationRead:(RecordSyncTag *)lastCalibrationRead;

@end