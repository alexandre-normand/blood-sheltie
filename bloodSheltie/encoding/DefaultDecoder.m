#import "DefaultDecoder.h"
#import "PageRange.h"
#import "EncodingUtils.h"
#import "RecordData.h"
#import "GlucoseReadRecord.h"
#import "ReadDatabasePageRangeRequest.h"
#import "UserEventRecord.h"
#import "TBXML.h"
#import "ManufacturingParameters.h"
#import "MeterReadRecord.h"
#import "GenericPayload.h"
#import "GlucoseUnitSetting.h"

static const int PAGE_HEADER_SIZE = 28;
static const int PAGE_DATA_SIZE = 500;
static const int FULL_PAGE_SIZE = PAGE_HEADER_SIZE + PAGE_DATA_SIZE;
static const uint32_t SPECIAL_GLUCOSE_VALUES[9] = {0u, 1u, 2u, 3u, 5u, 6u, 9u, 10u, 12u};
static const uint32_t GLUCOSE_DISPLAY_ONLY_MASK = 0x8000;
static const uint32_t GLUCOSE_READ_VALUE_MASK = 0x3ff;

uint32_t getRecordLength(RecordType recordType, NSData *data) {
    switch (recordType) {
        case EGVData:
            return 13;
        case UserEventData:
            return 20;
        case ManufacturingData:
            return [data length];
        case MeterData:
            return 16;
        default:
            return 0;
    }
}

@interface PagesPayloadHeader : NSObject
@property uint32_t firstRecordIndex;
@property uint32_t numberOfRecords;
@property RecordType recordType;
@property Byte revision;
@property uint32_t pageNumber;
@property uint32_t reserved2;
@property uint32_t reserved3;
@property uint32_t reserved4;

- (instancetype)initWithFirstRecordIndex:(uint32_t)firstRecordIndex numberOfRecords:(uint32_t)numberOfRecords recordType:(RecordType)recordType revision:(Byte)revision pageNumber:(uint32_t)pageNumber reserved2:(uint32_t)reserved2 reserved3:(uint32_t)reserved3 reserved4:(uint32_t)reserved4;

+ (instancetype)headerWithFirstRecordIndex:(uint32_t)firstRecordIndex numberOfRecords:(uint32_t)numberOfRecords recordType:(RecordType)recordType revision:(Byte)revision pageNumber:(uint32_t)pageNumber reserved2:(uint32_t)reserved2 reserved3:(uint32_t)reserved3 reserved4:(uint32_t)reserved4;

@end

@implementation PagesPayloadHeader
- (instancetype)initWithFirstRecordIndex:(uint32_t)firstRecordIndex numberOfRecords:(uint32_t)numberOfRecords recordType:(RecordType)recordType revision:(Byte)revision pageNumber:(uint32_t)pageNumber reserved2:(uint32_t)reserved2 reserved3:(uint32_t)reserved3 reserved4:(uint32_t)reserved4 {
    self = [super init];
    if (self) {
        self.firstRecordIndex = firstRecordIndex;
        self.numberOfRecords = numberOfRecords;
        self.recordType = recordType;
        self.revision = revision;
        self.pageNumber = pageNumber;
        self.reserved2 = reserved2;
        self.reserved3 = reserved3;
        self.reserved4 = reserved4;
    }

    return self;
}

+ (instancetype)headerWithFirstRecordIndex:(uint32_t)firstRecordIndex numberOfRecords:(uint32_t)numberOfRecords recordType:(RecordType)recordType revision:(Byte)revision pageNumber:(uint32_t)pageNumber reserved2:(uint32_t)reserved2 reserved3:(uint32_t)reserved3 reserved4:(uint32_t)reserved4 {
    return [[self alloc] initWithFirstRecordIndex:firstRecordIndex numberOfRecords:numberOfRecords recordType:recordType revision:revision pageNumber:pageNumber reserved2:reserved2 reserved3:reserved3 reserved4:reserved4];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"recordType=%s pageNumber=%d firstRecordindex=%d numberOfRecords=%d revision=%d", [[Types recordTypeIdentifier:_recordType] UTF8String],
                                      _pageNumber, _firstRecordIndex, _numberOfRecords, _revision];
}
@end

@implementation DefaultDecoder {

}

+ (ReceiverResponse *)decodeResponse:(NSData *)responseData toRequest:(ReceiverRequest *)request {
    NSLog(@"Decoding response for command %s", [[Types receiverCommandIdentifier:request.command] UTF8String]);

    NSUInteger currentPosition = 0;
    NSData *headerData = [responseData subdataWithRange:NSMakeRange(currentPosition, 4)];
    currentPosition += 4;

    ResponseHeader *header = [self decodeHeader:headerData];
    ResponsePayload *payload = [self decodePayload:[responseData subdataWithRange:NSMakeRange(currentPosition, responseData.length - currentPosition - sizeof(CRC))]
                                         ofCommand:request.command
                                         toRequest:request];

    [EncodingUtils validateCrc:responseData];

    ReceiverResponse *receiverResponse = [[ReceiverResponse alloc] initWithHeader:header andPayload:payload];

    return receiverResponse;
}

+ (ResponseHeader *)decodeHeader:(NSData *)header {
    NSUInteger currentPosition = 0;
    Byte sof;
    [header getBytes:&sof range:NSMakeRange(0, 1)];
    if (sof != 1) {
        NSLog(@"Invalid value [%d] for sof, always expecting 1", sof);
        return nil;
    }
    currentPosition++;

    uint16_t packetLength;
    [header getBytes:&packetLength range:NSMakeRange(currentPosition, 2)];
    packetLength = CFSwapInt16LittleToHost(packetLength);
    NSLog(@"Packet length is [%d]", packetLength);
    currentPosition += 2;

    ReceiverCommand command;
    [header getBytes:&command range:NSMakeRange(currentPosition, 1)];
    return [[ResponseHeader alloc] initWithCommand:command packetSize:packetLength];
}

+ (ResponsePayload *)decodePayload:(NSData *)payload ofCommand:(ReceiverCommand)command toRequest:(ReceiverRequest *)request {
    switch (command) {
        case ReadDatabasePageRange: {
            NSUInteger currentPosition = 0;

            uint32_t firstPage = 0;
            READ_UNSIGNEDINT(firstPage, currentPosition, payload);

            uint32_t lastPage = 0;
            READ_UNSIGNEDINT(lastPage, currentPosition, payload);

            ReadDatabasePageRangeRequest *pageRangeRequest = (ReadDatabasePageRangeRequest *) request;
            PageRange *range = [[PageRange alloc] initWithFirstPage:firstPage lastPage:lastPage ofRecordType:pageRangeRequest.recordType];
            return range;
        }

        case ReadDatabasePages: {
            NSMutableArray *pagesOfRecords = [[NSMutableArray alloc] init];
            NSUInteger currentPosition = 0;

            while (currentPosition < [payload length]) {
                NSUInteger remaining = [payload length] - currentPosition;
                NSUInteger pageSize = (NSUInteger) MIN(FULL_PAGE_SIZE, remaining);
                NSData *pageData = [payload subdataWithRange:NSMakeRange(currentPosition, pageSize)];
                currentPosition += pageSize;

                RecordData *recordData = [self readPageData:pageData];

                [pagesOfRecords addObject:recordData];
            }

            // Merge all RecordData into one using the record type from the first element.
            RecordType recordType = [[pagesOfRecords firstObject] recordType];
            NSMutableArray *allRecords = [[NSMutableArray alloc] init];

            for (id object in pagesOfRecords) {
                [allRecords addObjectsFromArray:[object records]];
            }

            return [[RecordData alloc] initWithRecordType:recordType records:allRecords];
        }
        case ReadGlucoseUnit: {
            NSUInteger currentPosition = 0;
            Byte content;
            READ_BYTE(content, currentPosition, payload);

            return [GlucoseUnitSetting payloadWithContent:content];
        }

        default: {
            return nil;
        }
    }
}

/**
 * Read one page of data from a response.
*/
+ (RecordData *)readPageData:(NSData *)pageData {
    NSUInteger current = 0;
    NSData *pageHeaderData = [pageData subdataWithRange:NSMakeRange(current, PAGE_HEADER_SIZE)];
    current += PAGE_HEADER_SIZE;

    PagesPayloadHeader *pageHeader = [self readPageHeader:pageHeaderData];
    NSData *pageContent = [pageData subdataWithRange:NSMakeRange(current, [pageData length] - current)];

    NSArray *pageRecords = [self readPageData:pageContent header:pageHeader];
    RecordData *recordData = [[RecordData alloc] initWithRecordType:pageHeader.recordType records:pageRecords];

    return recordData;
}

/**
* Read a page header
*/
+ (PagesPayloadHeader *)readPageHeader:(NSData *)data {
    NSUInteger currentPosition = 0;

    uint32_t firstRecordIndex;
    READ_UNSIGNEDINT(firstRecordIndex, currentPosition, data);

    uint32_t numberOfRecords;
    READ_UNSIGNEDINT(numberOfRecords, currentPosition, data);

    RecordType recordType;
    READ_BYTE(recordType, currentPosition, data);

    Byte revision;
    READ_BYTE(revision, currentPosition, data);

    uint32_t pageNumber;
    READ_UNSIGNEDINT(pageNumber, currentPosition, data);

    uint32_t reserved2;
    READ_UNSIGNEDINT(reserved2, currentPosition, data);

    uint32_t reserved3;
    READ_UNSIGNEDINT(reserved3, currentPosition, data);

    uint32_t reserved4;
    READ_UNSIGNEDINT(reserved4, currentPosition, data);

    [EncodingUtils validateCrc:data];

    return [[PagesPayloadHeader alloc] initWithFirstRecordIndex:firstRecordIndex numberOfRecords:numberOfRecords recordType:recordType revision:revision pageNumber:pageNumber reserved2:reserved2 reserved3:reserved3 reserved4:reserved4];
}

/**
* Read a page of data
*/
+ (NSArray *)readPageData:(NSData *)data header:(PagesPayloadHeader *)header {
    NSMutableArray *records = [[NSMutableArray alloc] init];
    NSLog(@"Parsing [%d] records...", header.numberOfRecords);
    uint32_t recordLength = getRecordLength(header.recordType, data);

    for (uint32_t i = 0; i < header.numberOfRecords; i++) {
        NSData *recordData = [data subdataWithRange:NSMakeRange(i * recordLength, recordLength)];

        NSObject *record = [self readRecord:recordData
                                 recordType:header.recordType
                               recordNumber:header.firstRecordIndex + i
                                 pageNumber:header.pageNumber];
        // If the record is nil, it means we ignored it because it's an internal record of special
        // value that we consider invalid
        if (record != nil) {
            [records addObject:record];
        }
    }

    return records;
}

/**
* Read a single record
*/
+ (NSObject *)readRecord:(NSData *)data recordType:(RecordType)type recordNumber:(uint32_t)recordNumber pageNumber:(uint32_t)pageNumber {
    switch (type) {
        case EGVData: {
            NSUInteger currentPosition = 0;
            uint32_t systemSeconds;
            READ_UNSIGNEDINT(systemSeconds, currentPosition, data);

            uint32_t displaySeconds;
            READ_UNSIGNEDINT(displaySeconds, currentPosition, data);

            uint16_t glucoseValueWithFlags;
            READ_UNSIGNEDSHORT(glucoseValueWithFlags, currentPosition, data);

            Byte trendAndArrowNoise;
            READ_BYTE(trendAndArrowNoise, currentPosition, data);

            [EncodingUtils validateCrc:data];


            NSInteger actualValue = [self getActualRecordValue:glucoseValueWithFlags];
            if (actualValue < 0) {
                // Yes, we create a record instance just for the log print but it might be useful
                GlucoseReadRecord *record = [[GlucoseReadRecord alloc] initWithInternalSecondsSinceDexcomEpoch:systemSeconds
                                                                                  localSecondsSinceDexcomEpoch:displaySeconds
                                                                                                  glucoseValue:glucoseValueWithFlags
                                                                                            trendArrowAndNoise:trendAndArrowNoise
                                                                                                  recordNumber:recordNumber
                                                                                                    pageNumber:pageNumber];
                NSLog(@"Internal record [%@] not valid for user, skipping...", record);
                return nil;
            } else {
                GlucoseReadRecord *record = [GlucoseReadRecord recordWithInternalSecondsSinceDexcomEpoch:systemSeconds
                                                                            localSecondsSinceDexcomEpoch:displaySeconds
                                                                                            glucoseValue:actualValue
                                                                                      trendArrowAndNoise:trendAndArrowNoise
                                                                                            recordNumber:recordNumber
                                                                                              pageNumber:pageNumber];
                return record;
            }
        }

        case UserEventData: {
            NSUInteger currentPosition = 0;
            uint32_t systemSeconds;
            READ_UNSIGNEDINT(systemSeconds, currentPosition, data);

            uint32_t displaySeconds;
            READ_UNSIGNEDINT(displaySeconds, currentPosition, data);

            UserEventType eventType;
            READ_BYTE(eventType, currentPosition, data);

            Byte eventSubType;
            READ_BYTE(eventSubType, currentPosition, data);

            uint32_t eventLocalTimeInSeconds;
            READ_UNSIGNEDINT(eventLocalTimeInSeconds, currentPosition, data);

            uint32_t eventValue;
            READ_UNSIGNEDINT(eventValue, currentPosition, data);

            [EncodingUtils validateCrc:data];

            return [UserEventRecord recordWithEventType:eventType
                                                subType:eventSubType
                                             eventValue:eventValue
                           eventSecondsSinceDexcomEpoch:eventLocalTimeInSeconds
                        internalSecondsSinceDexcomEpoch:systemSeconds
                           localSecondsSinceDexcomEpoch:displaySeconds
                                           recordNumber:recordNumber
                                             pageNumber:pageNumber];
        }

        case ManufacturingData: {
            NSUInteger currentPosition = 0;
            uint32_t systemSeconds;
            READ_UNSIGNEDINT(systemSeconds, currentPosition, data);

            uint32_t displaySeconds;
            READ_UNSIGNEDINT(displaySeconds, currentPosition, data);

            NSUInteger length = [data length] - currentPosition - sizeof(CRC);
            NSData *content = [data subdataWithRange:NSMakeRange(currentPosition, length)];
            ManufacturingParameters *parameters = [self parseManufacturingParameters:content currentPosition:currentPosition];

            [EncodingUtils validateCrc:data];

            return parameters;
        }

        case MeterData: {
            NSUInteger currentPosition = 0;
            uint32_t systemSeconds;
            READ_UNSIGNEDINT(systemSeconds, currentPosition, data);

            uint32_t displaySeconds;
            READ_UNSIGNEDINT(displaySeconds, currentPosition, data);

            uint16_t meterRead;
            READ_UNSIGNEDSHORT(meterRead, currentPosition, data);

            uint32_t meterTime;
            READ_UNSIGNEDINT(meterTime, currentPosition, data);

            [EncodingUtils validateCrc:data];

            return [MeterReadRecord recordWithMeterRead:meterRead
                        internalSecondsSinceDexcomEpoch:systemSeconds
                           localSecondsSinceDexcomEpoch:displaySeconds
                     meterTimeInSecondsSinceDexcomEpoch:meterTime
                                           recordNumber:recordNumber
                                             pageNumber:pageNumber];
        }
        default:
            return nil;

    }

}

+ (NSInteger)getActualRecordValue:(uint16_t)rawValue {
    bool isDisplayOnly = (rawValue & GLUCOSE_DISPLAY_ONLY_MASK) != 0;
    if (isDisplayOnly) {
        return -1;
    } else {
        uint32_t actualValue = rawValue & GLUCOSE_READ_VALUE_MASK;
        for (int i = 0; i < 9; i++) {
            if (actualValue == SPECIAL_GLUCOSE_VALUES[i]) {
                return -1;
            }
        }

        return actualValue;
    }
}

+ (ManufacturingParameters *)parseManufacturingParameters:(NSData *)data currentPosition:(NSUInteger)currentPosition {
    NSError *error;
    TBXML *xmlContent = [TBXML newTBXMLWithXMLData:data error:&error];

    ManufacturingParameters *parameters = [ManufacturingParameters alloc];
    if (error) {
        NSLog(@"%@ %@", [error localizedDescription], [error userInfo]);
    } else {
        TBXMLElement *element = [xmlContent rootXMLElement];
        // Obtain first attribute from element
        TBXMLAttribute *attribute = element->firstAttribute;

        NSString *serialNumber;
        NSString *hardwarePartNumber;
        NSString *hardwareRevision;
        NSString *dateTimeCreated;
        NSString *hardwareId;
        // if attribute is valid
        while (attribute) {
            // Display name and value of attribute to the log window
            NSString *attributeName = [TBXML attributeName:attribute];

            if ([attributeName isEqualToString:@"SerialNumber"]) {
                serialNumber = [TBXML attributeValue:attribute];
            } else if ([attributeName isEqualToString:@"HardwarePartNumber"]) {
                hardwarePartNumber = [TBXML attributeValue:attribute];
            } else if ([attributeName isEqualToString:@"HardwareRevision"]) {
                hardwareRevision = [TBXML attributeValue:attribute];
            } else if ([attributeName isEqualToString:@"DateTimeCreated"]) {
                dateTimeCreated = [TBXML attributeValue:attribute];
            } else if ([attributeName isEqualToString:@"HardwareId"]) {
                hardwareId = [TBXML attributeValue:attribute];
            }

            // Obtain the next attribute
            attribute = attribute->next;
        }

        parameters = [parameters initWithSerialNumber:serialNumber hardwarePartNumber:hardwarePartNumber hardwareRevision:hardwareRevision dateTimeCreated:dateTimeCreated hardwareId:hardwareId];
    }
    return parameters;
}

@end