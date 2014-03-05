#import "ReceiverRequest.h"


@implementation ReceiverRequest {

}
- (id)initWithCommand:(ReceiverCommand)command {
    if (self = [super init]) {
        _command = command;
        _commandSize = 6;
        _sizeOfField = 1;
    }

    return self;
}

- (uint16_t)getCommandSize {
    return _commandSize;
}

- (NSString *)description {
    return [NSString stringWithFormat: @"Request: command=%s commandSize=%d",
                    [[Types receiverCommandIdentifier:_command] UTF8String], _commandSize];
}

@end