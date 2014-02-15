#import "FreshDataFetcher.h"
#import "EncodingUtils.h"
#import "DefaultEncoder.h"
#import "ReadDatabasePageRangeRequest.h"
#import "DefaultDecoder.h"
#import "DataPaginator.h"
#import "ReadDatabasePagesRequest.h"
#import "RecordData.h"

static const uint HEADER_SIZE = 4;

/**
* Handles accumulating the data for a response.
*/
@interface ResponseAccumulator : NSObject

- (NSData *)processData:(NSData *)data asResponseTo:(ReceiverRequest *)request;
@end

@implementation ResponseAccumulator
bool responseInFlight;
NSMutableData *responseBuffer;
ResponseHeader *responseHeader;

+ (void)initialize {
    responseInFlight = false;
    responseBuffer = nil;
    responseHeader = nil;
}

- (NSData *)processData:(NSData *)data asResponseTo:(ReceiverRequest *)request {

    if (!responseInFlight) {
        NSLog(@"Reading response header for command %s", [[Types receiverCommandIdentifier:request.command] UTF8String]);
        NSData *headerData = [data subdataWithRange:NSMakeRange(0, HEADER_SIZE)];

        responseHeader = [DefaultDecoder decodeHeader:headerData];
        NSLog(@"Expecting [%d] bytes, including header", responseHeader.packetSize);

        // Create a new buffer for this new response
        responseBuffer = [[NSMutableData alloc] init];
        responseInFlight = true;
    }

    return [self handleDataAndFillBuffer:data];
}

/**
* Handles a chunk of data and either triggers the processing of the response (if we have all the packet)
* or it accumulates the data until we receive the rest.
*/
- (NSData *)handleDataAndFillBuffer:(NSData *)data {
    [responseBuffer appendData:data];
    NSLog(@"Added [%lu] bytes to buffer for total of [%lu] bytes", [data length], [responseBuffer length]);

    if ([responseBuffer length] == responseHeader.packetSize) {
        NSLog(@"Packet fully received: [%s]",
                [[EncodingUtils bytesToString:[responseBuffer bytes] withSize:[data length]] UTF8String]);

        NSData *fullPacket = [[NSData alloc] initWithData:responseBuffer];

        // Reset state
        responseBuffer = nil;
        responseHeader = nil;
        responseInFlight = false;

        return fullPacket;
    }

    return nil;
}


@end

@implementation FreshDataFetcher {
    ORSSerialPort *port;
    NSMutableArray *sessionRequests;
    DefaultEncoder *encoder;
    ReceiverRequest *currentRequest;
    ResponseAccumulator *responseAccumulator;
}

- (instancetype)initWithSerialPortPath:(NSString *)serialPortPath since:(NSDate *)since {
    self = [super init];
    if (self) {
        _serialPortPath = serialPortPath;
        _since = since;
        _observers = [[NSMutableArray alloc] init];
        _sessionData = [[SyncData alloc] init];
        encoder = [[DefaultEncoder alloc] init];
        responseAccumulator = [[ResponseAccumulator alloc] init];
    }

    return self;
}

+ (instancetype)fetcherWithSerialPortPath:(NSString *)serialPortPath since:(NSDate *)since {
    return [[self alloc] initWithSerialPortPath:serialPortPath since:since];
}

- (void)run {
    sessionRequests = [self generateInitialRequestFlow];

    // Open the port and initiate the download session
    port = [ORSSerialPort serialPortWithPath:_serialPortPath];
    [port setDelegate:self];
    [port setBaudRate:@115200];
    [port setNumberOfStopBits:1];
    [port setParity:ORSSerialPortParityNone];
    [port setUsesRTSCTSFlowControl:true];
    [port setRTS:true];
    [port setDTR:true];
    [port open];

    // When we get a Clear-To-Send, we'll start the session
    [port addObserver:self forKeyPath:@"CTS" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (NSMutableArray *)generateInitialRequestFlow {
    NSMutableArray *requests = [[NSMutableArray alloc] init];
    [requests addObject:[[ReceiverRequest alloc] initWithCommand:Ping]];
    [requests addObject:[[ReadDatabasePageRangeRequest alloc] initWithRecordType:ManufacturingData]];
    [requests addObject:[[ReadDatabasePageRangeRequest alloc] initWithRecordType:MeterData]];
    [requests addObject:[[ReadDatabasePageRangeRequest alloc] initWithRecordType:UserEventData]];
    [requests addObject:[[ReadDatabasePageRangeRequest alloc] initWithRecordType:EGVData]];

    return requests;
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data {
    NSLog(@"Received data: %s\n", [[EncodingUtils bytesToString:(Byte *) [data bytes] withSize:data.length] UTF8String]);

    NSData *packet = [responseAccumulator processData:data asResponseTo:currentRequest];
    // Packet is fully received, process it
    if (packet != nil) {
        // Packet done, decode the response
        [self handleResponseData:packet];
    }
}

/**
* Handles a full response once it's fully received
*/
- (void)handleResponseData:(NSData *)data {
    ReceiverResponse *response = [DefaultDecoder decodeResponse:data toRequest:currentRequest];
    NSLog(@"Decoded response %@ from bytes [%s]", response,
            [[EncodingUtils bytesToString:[data bytes] withSize:[data length]] UTF8String]);
    
    [self addSessionDataFromResponse:response toRequest:currentRequest];
    [self notifySyncProgress];

    [sessionRequests removeObject:currentRequest];
    NSLog(@"Removed request [%@] from queue", currentRequest);

    NSArray *requests = [self newRequestsFromResponse:response toRequest:currentRequest];

    if (requests != nil) {
        NSLog(@"Adding [%lu] requests", [requests count]);
        [sessionRequests addObjectsFromArray:requests];
    } else {
        NSLog(@"No requests to spawn from response [%@] to request [%@]", response, currentRequest);
    }

    if ([sessionRequests count] > 0) {
        [self sendRequest:[sessionRequests firstObject]];
    } else {
        [self notifySyncComplete];
    }
}

- (void)notifySyncProgress {
    NSLog(@"Notifying all observers of sync progress.");
    for (id observer in _observers) {
        [observer syncProgress:[[SyncEvent alloc] initWithDevicePath:port.path sessionData:_sessionData]];
    }
}

- (void)notifySyncComplete {
    NSLog(@"Notifying all observers of sync completion.");
    for (id observer in _observers) {
        [observer syncComplete:[[SyncEvent alloc] initWithDevicePath:port.path sessionData:_sessionData]];
    }
}

- (void)addSessionDataFromResponse:(ReceiverResponse *)response toRequest:(ReceiverRequest *)request {
    if ([request class] == [ReadDatabasePagesRequest class]) {
        RecordData *recordData = (RecordData *) response.payload;

        switch (recordData.recordType) {
            case EGVData:
                [_sessionData.glucoseReads addObjectsFromArray:recordData.records];
                break;
            case ManufacturingData:
                // We'll only have one record of ManufacturingData
                _sessionData.manufacturingParameters = [recordData.records firstObject];
                break;
            case MeterData:
                [_sessionData.calibrationReads addObjectsFromArray:recordData.records];
                break;
            case UserEventData:
                [_sessionData.userEvents addObjectsFromArray:recordData.records];
                break;
            default:
                break;
        }
    }
}

- (NSArray *)newRequestsFromResponse:(ReceiverResponse *)response toRequest:(ReceiverRequest *)request {
    switch (request.command) {
        case ReadDatabasePageRange: {
            PageRange *pageRange = (PageRange *) response.payload;
            return [DataPaginator getDatabasePagesRequestsForRecordType:pageRange.recordType andPageRange:pageRange];
        }
        case ReadDatabasePages:
            return nil;
        default:
            return nil;
    }
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort {
    NSLog(@"serial port disconnected: %s\n", [serialPort.name UTF8String]);
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error {
    NSLog(@"Error: %@", error);
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort {
    NSLog(@"Serial port open: %s\n", [[serialPort name] UTF8String]);
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort {
    NSLog(@"Serial port closed: %s\n", [[serialPort name] UTF8String]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, object, keyPath);
    NSLog(@"Change dictionary: %@", change);

    NSString *portName = ((ORSSerialPort *) object).name;
    if (port == nil) {
        NSLog(@"Port not open, this must mean this CTS change is for another device [%s]", [portName UTF8String]);
    }

    if (![portName isEqual:port.name]) {
        NSLog(@"Received CTS change for another device [%s], ignoring...", [portName UTF8String]);
        return;
    }

    [self notifySyncStarted];
    [self sendRequest:[sessionRequests firstObject]];
}

- (void)notifySyncStarted {
    NSLog(@"Notifying all observers of sync start.");
    for (id observer in _observers) {
        [observer syncStarted:[[SyncEvent alloc] initWithDevicePath:port.path sessionData:_sessionData]];
    }
}

- (void)sendRequest:(ReceiverRequest *)request {
    currentRequest = request;

    void const *bytes = [encoder encodeRequest:request];
    NSData *dataToSend = [NSData dataWithBytes:bytes length:request.getCommandSize];
    char const *bytesAsString = [[EncodingUtils bytesToString:(Byte *) bytes withSize:request.getCommandSize] UTF8String];
    NSLog(@"Sending request to the device: %@\n", request);
    BOOL status = [port sendData:dataToSend];
    NSLog(@"Sent [%s] bytes to the device with status: %s\n", bytesAsString, !status ? "false" : "true");
}


@end