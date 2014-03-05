#import <Foundation/Foundation.h>
#import "ResponsePayload.h"
#import "Types.h"

@interface PageRange : ResponsePayload
@property(readonly) uint32_t firstPage;
@property(readonly) uint32_t lastPage;
@property(readonly) RecordType recordType;

- (instancetype)initWithFirstPage:(uint32_t)firstPage lastPage:(uint32_t)lastPage ofRecordType:(RecordType)recordType;

+ (instancetype)rangeWithFirstPage:(uint32_t)firstPage lastPage:(uint32_t)lastPage ofRecordType:(RecordType)recordType;

@end