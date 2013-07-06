//
//  RSViewController.m
//  GKMatchPacketLostExample
//
//  Created by Yan Rabovik on 18.06.13.
//  Copyright (c) 2013 Yan Rabovik. All rights reserved.
//

#define BASE_MESSAGE_SIZE 100

#import "RSViewController.h"
#import "NSString+CRC32.h"

@interface RSViewController ()<GKMatchmakerViewControllerDelegate,GKMatchDelegate>{
    NSUInteger sentCount,receivedCount,errorsCount;
}

@property (weak, nonatomic) IBOutlet UIButton *hostMatchButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;

@property (weak, nonatomic) IBOutlet UITextField *sentField;
@property (weak, nonatomic) IBOutlet UITextField *receivedField;
@property (weak, nonatomic) IBOutlet UITextField *errorsField;
@property (weak, nonatomic) IBOutlet UITextView *sentTextView;
@property (weak, nonatomic) IBOutlet UITextView *receivedTextView;
@property (weak, nonatomic) IBOutlet UITextView *errorsTextView;

@property (nonatomic,strong) GKMatch *myMatch;
@property (nonatomic) BOOL matchStarted;
@property (nonatomic) BOOL matchStopped;

@property (nonatomic,strong) NSTimer *sendingTimer;
@property (nonatomic,strong) NSTimer *receivedTimer;

@property (nonatomic) NSUInteger lastReceivedMessageNumber;
@property (nonatomic) NSDate *lastReceivedDate;
@end

@implementation RSViewController

#pragma mark - View lyfeyicle

-(void)viewDidLoad{
    [super viewDidLoad];
    [self authenticateLocalPlayer];
}

- (void)viewDidUnload {
    [self setHostMatchButton:nil];
    [self setStopButton:nil];
    [self setSentField:nil];
    [self setReceivedField:nil];
    [self setSentTextView:nil];
    [self setErrorsField:nil];
    [self setReceivedTextView:nil];
    [self setErrorsTextView:nil];
    [super viewDidUnload];
}

#pragma mark - UI responders
- (IBAction)hostButtonClicked:(id)sender {
    [self hostMatch];
}

- (IBAction)stopButtonClickes:(id)sender {
    [self stopSending];
}

#pragma mark - Authentication
-(void)authenticateLocalPlayer{
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    __typeof(self) __weak weakSelf = self;
    [localPlayer authenticateWithCompletionHandler:^(NSError *error) {
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            if (localPlayer.isAuthenticated){
                self.hostMatchButton.enabled = YES;
            }
        }
    }];
}

#pragma mark - Host match
-(void)hostMatch{
    GKMatchRequest *request = [GKMatchRequest new];
    request.minPlayers = 2;
    request.maxPlayers = 2;
    GKMatchmakerViewController *mmvc =
        [[GKMatchmakerViewController alloc] initWithMatchRequest:request];
    mmvc.matchmakerDelegate = self;
    [self presentViewController:mmvc animated:YES completion:nil];
}
         
-(void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)matchmakerViewController:(GKMatchmakerViewController *)viewController
               didFailWithError:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [self logError:[NSString stringWithFormat:
                    @"GKMatchmakerViewController did fail with error: %@",
                    error]];
}

-(void)matchmakerViewController:(GKMatchmakerViewController *)viewController
                   didFindMatch:(GKMatch *)match
{
    [self logSent:[NSString stringWithFormat:
                   @"Did find match. Match started=%d. Expected player count=%u",
                   self.matchStarted,
                   match.expectedPlayerCount]];
    [self dismissViewControllerAnimated:YES completion:nil];
    self.myMatch = match;
    match.delegate = self;
    if (!self.matchStarted && match.expectedPlayerCount == 0){
        [self startMatch];
    }    
}

-(void)    match:(GKMatch *)match
          player:(NSString *)playerID
  didChangeState:(GKPlayerConnectionState)state
{
    if (GKPlayerStateConnected == state) {
        [self logSent:[NSString stringWithFormat:
                       @"Player connected. Match started=%d. Expected player count=%u",
                       self.matchStarted,
                       match.expectedPlayerCount]];

        if (!self.matchStarted && match.expectedPlayerCount == 0){
            [self startMatch];
        }
    }else{
        [self stopSending];
        [self logError:@"Player disconnected."];
    }
}
-(void)match:(GKMatch *)match didFailWithError:(NSError *)error{
    [self stopSending];
    [self logError:[NSString stringWithFormat:
                    @"Match did fail with error: %@",
                    error]];
}


#pragma mark - Send data
-(void)startMatch{
    if (self.myMatch.playerIDs.count == 0) {
        [self logError:@"Match failed. Expected player count is 0, but players array is empty."];
        return;
    }
    [self logSent:@"Match started."];
    self.matchStarted = YES;
    self.stopButton.hidden = NO;
    self.hostMatchButton.hidden = YES;
    [self sheduleTimer];
}

-(void)sheduleTimer{
    [self.sendingTimer invalidate];
    NSTimeInterval interval = 0.1f + 0.1f*(arc4random()%10);
    if (arc4random()%15 == 0) {
        interval += 5.0f + arc4random()%15;
    }
    self.sendingTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                         target:self
                                                       selector:@selector(timerFired:)
                                                       userInfo:nil
                                                        repeats:NO];
}

-(void)timerFired:(NSTimer *)timer{
    [self sendMessage];
    [self sheduleTimer];
}

-(void)stopSending{
    [self.sendingTimer invalidate];
    self.sendingTimer = nil;
    [self.receivedTimer invalidate];
    self.receivedTimer = nil;
    [self logError:@"Stopped."];
}

-(void)sendMessage{
    static unichar characters[BASE_MESSAGE_SIZE*10];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (int x=0;x<BASE_MESSAGE_SIZE*10;++x){
            characters[x] = (unichar)(('A')+arc4random_uniform(26));
        };
    });
    NSUInteger messageLength = BASE_MESSAGE_SIZE/2+arc4random()%(BASE_MESSAGE_SIZE/2);
    if (arc4random()%3 == 0) {
        messageLength = arc4random() %10;
    }
    if (arc4random()%15 == 0) {
        messageLength *= 10;
    }

    NSString *message =
        [NSString stringWithCharacters:characters length:messageLength];
    ++sentCount;
    unsigned long crc32 = [message crc32];
    NSError *error = NULL;
    NSData *data = [NSJSONSerialization
                    dataWithJSONObject:@{@"num":@(sentCount),
                                         @"message":message,
                                         @"crc":@(crc32)}
                    options:0
                    error:&error];
    if (error != nil || nil == data){
        [self stopSending];
        [self logError:@"JSON encoding error."];
        return;
    }
    [self.myMatch sendDataToAllPlayers:data
                          withDataMode:GKMatchSendDataReliable
                                 error:&error];
	if (error != nil){
        [self stopSending];
        [self logError:@"sendDataToAllPlayers error"];
        return;
    }
    [self logSent:[NSString stringWithFormat:
                   @"%u) length=%u",
                   sentCount,
                   [data length]]];
}

#pragma mark - Receive data
-(void)    match:(GKMatch *)match
  didReceiveData:(NSData *)data
      fromPlayer:(NSString *)playerID
{
    [self.receivedTimer invalidate];
    
    NSError *error;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&error];
    if (error != nil){
        [self stopSending];
        [self logError:@"JSON decoding error."];
        return;
    }
    if (![jsonDict isKindOfClass:[NSDictionary class]]) {
        ++errorsCount;
        [self logError:[NSString stringWithFormat:
                        @"%u) Corrupted data. Expected NSDictionary.",
                        errorsCount]];
        return;
    }
    NSNumber *receivedNumber = [jsonDict objectForKey:@"num"];
    if (![receivedNumber isKindOfClass:[NSNumber class]]) {
        ++errorsCount;
        [self logError:[NSString stringWithFormat:
                        @"%u) Corrupted data. Expected NSNumber for 'num'.",
                        errorsCount]];
        return;
    }
    NSNumber *crcNumber = [jsonDict objectForKey:@"crc"];
    if (![crcNumber isKindOfClass:[NSNumber class]]) {
        ++errorsCount;
        [self logError:[NSString stringWithFormat:
                        @"%u) Corrupted data. Expected NSNumber for 'crc'.",
                        errorsCount]];
        return;
    }
    NSString *message = [jsonDict objectForKey:@"message"];
    if (![message isKindOfClass:[NSString class]]) {
        ++errorsCount;
        [self logError:[NSString stringWithFormat:
                        @"%u) Corrupted data. Expected NSString for 'message'.",
                        errorsCount]];
        return;
    }
    if ([crcNumber unsignedLongValue] != [message crc32]) {
        ++errorsCount;
        [self logError:[NSString stringWithFormat:
                        @"%u) Corrupted data. Wrong CRC32.",
                        errorsCount]];
        return;
    }
    ++receivedCount;
    NSUInteger receivedN = [receivedNumber unsignedIntegerValue];
    [self logReceived:[NSString stringWithFormat:
                       @"%u) №:%u length=%u",
                       receivedCount,
                       receivedN,
                       [data length]]];
    if (receivedN != self.lastReceivedMessageNumber+1) {
        ++errorsCount;
        [self logError:[NSString stringWithFormat:
                        @"%u) Received №%u, expected №%u",
                        errorsCount,
                        receivedN,
                        self.lastReceivedMessageNumber+1]];
    }
    self.lastReceivedMessageNumber = receivedN;
    self.lastReceivedDate = [NSDate date];
    [self sheduleReceivedTimer];
}

-(void)sheduleReceivedTimer{
    [self.receivedTimer invalidate];
    self.receivedTimer = [NSTimer
                          scheduledTimerWithTimeInterval:30.f
                          target:self
                          selector:@selector(receivedTimerFired:)
                          userInfo:nil
                          repeats:YES];
}

-(void)receivedTimerFired:(NSTimer *)timer{
    NSUInteger seconds =
        round([[NSDate date] timeIntervalSinceDate:self.lastReceivedDate]);
    [self logError:[NSString stringWithFormat:
                    @"Not receiving messages for %u seconds",
                    seconds]];
}

#pragma mark - Logging
-(void)logSent:(NSString *)message{
    NSLog(@"%u) Sent: %@",sentCount,message);
    [self logToView:self.sentTextView message:message];
    [self updateCountField:self.sentField count:sentCount];
}

-(void)logReceived:(NSString *)message{
    NSLog(@"%u) Received: %@",receivedCount,message);
    [self logToView:self.receivedTextView message:message];
    [self updateCountField:self.receivedField count:receivedCount];
}

-(void)logError:(NSString *)message{
    NSLog(@"%u) Error: %@",errorsCount,message);
    [self logToView:self.errorsTextView message:message];
    [self updateCountField:self.errorsField count:errorsCount];
}

-(void)logToView:(UITextView *)textView message:(NSString *)message{
    NSString *text = [textView.text stringByAppendingFormat:@"%@\n",message];
    textView.text = text;
    NSRange range = NSMakeRange(textView.text.length - 1, 1);
    [textView scrollRangeToVisible:range];
}

-(void)updateCountField:(UITextField *)field count:(NSUInteger)count{
    field.text = [NSString stringWithFormat:@"%u",count];
}

@end
