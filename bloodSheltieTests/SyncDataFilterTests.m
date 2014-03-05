//
//  SyncDataFilterTests.m
//  blood-sheltie
//
//  Created by Alexandre Normand on 2/20/2014.
//  Copyright (c) 2014 glukit. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "InternalSyncData.h"
#import "SyncDataFilter.h"
#import "Types.h"
#import "MeterReadRecord.h"
#import "UserEventRecord.h"
#import "GlucoseReadRecord.h"
#import "SyncTag.h"

@interface SyncDataFilterTests : XCTestCase

@end

@implementation SyncDataFilterTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testEmptySyncDataFiltersWithoutErrors
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [SyncDataFilter sortAndFilterData:data withSyncTag:NULL since:[Types dexcomEpoch]];
}

- (void)testCalibrationReadsFilterWithDataBeforeAndAfterDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 meterTimeInSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:101 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.calibrationReads count], 1ul);
}

- (void)testUserEventsFilterWithDataBeforeAndAfterDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:2 eventSecondsSinceDexcomEpoch:100 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:4 eventSecondsSinceDexcomEpoch:1000 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:101 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.userEvents count], 1ul);
}

- (void)testGlucoseReadsFilterWithDataBeforeAndAfterDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:101 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.glucoseReads count], 1ul);
}

- (void)testCalibrationReadsFilterWithDataAllBeforeDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 meterTimeInSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:1001 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.calibrationReads count], 0ul);
}

- (void)testUserEventsFilterWithDataAllBeforeDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:2 eventSecondsSinceDexcomEpoch:100 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:4 eventSecondsSinceDexcomEpoch:1000 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:1001 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.userEvents count], 0ul);
}

- (void)testGlucoseReadsFilterWithDataAllBeforeDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:1001 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.glucoseReads count], 0ul);
}

// Put the records out-of-order and expect the filtering to return them sorted
- (void)testDataSorted
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:1 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 meterTimeInSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:99 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.calibrationReads count], 2ul);
    
    MeterReadRecord *firstRecord = [filteredData.calibrationReads objectAtIndex:0];
    XCTAssertEqual(firstRecord.recordNumber, 0u);
    MeterReadRecord *secondRecord = [filteredData.calibrationReads objectAtIndex:1];
    XCTAssertEqual(secondRecord.recordNumber, 1u);
}

- (void)testCalibrationReadsFilterWithDataAllAfterDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 meterTimeInSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:99 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.calibrationReads count], 2ul);
}

- (void)testUserEventsFilterWithDataAllAfterDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:2 eventSecondsSinceDexcomEpoch:100 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:4 eventSecondsSinceDexcomEpoch:1000 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:99 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.userEvents count], 2ul);
}

- (void)testGlucoseReadsFilterWithDataAllAfterDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:99 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.glucoseReads count], 2ul);
}

- (void)testCalibrationReadsFilterWithDataExactlyOnDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 meterTimeInSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:100 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.calibrationReads count], 1ul);
}

- (void)testUserEventsFilterWithDataExactlyOnDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:2 eventSecondsSinceDexcomEpoch:100 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 recordNumber:0 pageNumber:0]];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:4 eventSecondsSinceDexcomEpoch:1000 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:100 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.userEvents count], 1ul);
}

- (void)testGlucoseReadsFilterWithDataExactlyOnDate
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 glucoseValue:83 trendArrowAndNoise:0 recordNumber:0 pageNumber:0]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:[SyncTag initialSyncTag] since:[NSDate dateWithTimeInterval:100 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.glucoseReads count], 1ul);
}

- (void)testCalibrationReadsFilterWithIncrementalSyncTag
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 meterTimeInSecondsSinceDexcomEpoch:100 recordNumber:9 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:10 pageNumber:0]];
    [data.calibrationReads addObject:[MeterReadRecord recordWithMeterRead:10 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 meterTimeInSecondsSinceDexcomEpoch:1000 recordNumber:11 pageNumber:0]];
    SyncTag *syncTag = [SyncTag tagWithSerialNumber:@"test" lastGlucoseRead:[RecordSyncTag initialSyncTag] lastUserEvent:[RecordSyncTag initialSyncTag] lastCalibrationRead:[RecordSyncTag tagWithRecordNumber:@10 pageNumber:@100]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:syncTag since:[NSDate dateWithTimeInterval:0 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.calibrationReads count], 1ul);
}

- (void)testGlucoseReadsFilterWithIncrementalSyncTag
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 glucoseValue:83 trendArrowAndNoise:0 recordNumber:9 pageNumber:0]];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 glucoseValue:83 trendArrowAndNoise:0 recordNumber:10 pageNumber:0]];
    [data.glucoseReads addObject:[GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 glucoseValue:83 trendArrowAndNoise:0 recordNumber:11 pageNumber:0]];
    SyncTag *syncTag = [SyncTag tagWithSerialNumber:@"test" lastGlucoseRead:[RecordSyncTag tagWithRecordNumber:@10 pageNumber:@100] lastUserEvent:[RecordSyncTag initialSyncTag] lastCalibrationRead:[RecordSyncTag initialSyncTag]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:syncTag since:[NSDate dateWithTimeInterval:0 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.glucoseReads count], 1ul);
}

- (void)testUserEventsFilterWithIncrementalSyncTag
{
    InternalSyncData *data = [[InternalSyncData alloc] init];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:2 eventSecondsSinceDexcomEpoch:100 internalSecondsSinceDexcomEpoch:100 localSecondsSinceDexcomEpoch:100 recordNumber:9 pageNumber:0]];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:4 eventSecondsSinceDexcomEpoch:1000 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 recordNumber:10 pageNumber:0]];
    [data.userEvents addObject:[UserEventRecord recordWithEventType:Insulin subType:0 eventValue:4 eventSecondsSinceDexcomEpoch:1000 internalSecondsSinceDexcomEpoch:1000 localSecondsSinceDexcomEpoch:1000 recordNumber:11 pageNumber:0]];
    SyncTag *syncTag = [SyncTag tagWithSerialNumber:@"test" lastGlucoseRead:[RecordSyncTag initialSyncTag] lastUserEvent:[RecordSyncTag tagWithRecordNumber:@10 pageNumber:@100] lastCalibrationRead:[RecordSyncTag initialSyncTag]];
    InternalSyncData *filteredData = [SyncDataFilter sortAndFilterData:data withSyncTag:syncTag since:[NSDate dateWithTimeInterval:0 sinceDate:[Types dexcomEpoch]]];
    XCTAssertEqual([filteredData.userEvents count], 1ul);
}

@end
