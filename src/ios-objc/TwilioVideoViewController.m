//
//  TwilioVideoViewController.m
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

#import <TwilioVideo/TwilioVideo.h>
#import "TwilioVideoViewController.h"


#import <Foundation/Foundation.h>

@interface PlatformUtils : NSObject

+ (BOOL)isSimulator;

@end

@implementation PlatformUtils

+ (BOOL)isSimulator {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#endif
    return NO;
}

@end

@interface XXTwilioVideoViewController () <UITextFieldDelegate, TVILocalParticipantDelegate, TVIRemoteParticipantDelegate, TVIRoomDelegate, TVIVideoViewDelegate, TVICameraCapturerDelegate>

#pragma mark Video SDK components

@property (nonatomic, strong) TVICameraCapturer *camera;
@property (nonatomic, strong) TVILocalVideoTrack *localVideoTrack;
@property (nonatomic, strong) TVILocalAudioTrack *localAudioTrack;
@property (nonatomic, strong) TVIRemoteParticipant *remoteParticipant;
@property (nonatomic, weak) TVIVideoView *remoteView;
@property (nonatomic, strong) TVIRoom *room;

#pragma mark UI Element Outlets and handles



// `TVIVideoView` created from a storyboard
@property (weak, nonatomic) IBOutlet TVIVideoView *previewView;

@property (nonatomic, weak) IBOutlet UIButton *disconnectButton;    
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;
@property (nonatomic, weak) IBOutlet UIButton *micButton;
@property (nonatomic, weak) IBOutlet UIButton *flipCameraButton;
@property (nonatomic, weak) IBOutlet UIButton *videoButton;

@end

@implementation XXTwilioVideoViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self logMessage:[NSString stringWithFormat:@"TwilioVideo v%@", [TwilioVideo version]]];
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    //  self.accessToken = @"TWILIO_ACCESS_TOKEN";
    
    
    // Preview our local camera track in the local video preview view.
    [self startPreview];
    
    // Disconnect and mic button will be displayed when client is connected to a room.
    // self.disconnectButton.hidden = YES;
    // self.micButton.hidden = YES;
    
//    self.roomTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
//    self.roomTextField.delegate = self;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.remoteView addGestureRecognizer:tap];
}

#pragma mark - Public

- (void)connectToRoom:(NSString*)room withToken:(NSString *)accessToken {
    [self showRoomUI:YES];
    
//    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
//        self.accessToken = accessToken;
//        [self logMessage:[NSString stringWithFormat:@"Fetching an access token"]];
//        [self showRoomUI:NO];
//    } else {
    [self doConnect:room withToken:accessToken];
//    }
}

- (IBAction)disconnectButtonPressed:(id)sender {
    [self.room disconnect];
    [self dismissViewControllerAnimated:true completion:nil];
}

- (IBAction)micButtonPressed:(id)sender {
    // We will toggle the mic to mute/unmute and change the title according to the user action.
    
    if (self.localAudioTrack) {
        self.localAudioTrack.enabled = !self.localAudioTrack.isEnabled;
        
        // Toggle the button title
        if (self.localAudioTrack.isEnabled) {
            [self.micButton setTitle:@"Mute" forState:UIControlStateNormal];
        } else {
            [self.micButton setTitle:@"Unmute" forState:UIControlStateNormal];
        }
    }
}

- (IBAction)flipcameraButtonPressed:(id)sender {
    if (self.localVideoTrack) {
        //  self.flipCameraButton.selected = !self.flipCameraButton.selected;
        //  self.flipCameraButton.alpha = self.flipCameraButton.selected ? 0.7 : 1;
        [self flipCamera];
    }
}

- (IBAction)videoButtonPressed:(id)sender {
    if (self.localVideoTrack) {
        self.localVideoTrack.enabled = !self.localVideoTrack.isEnabled;
        
        if (self.localVideoTrack.isEnabled) {
            self.videoButton.selected=false;
            self.videoButton.alpha = self.videoButton.selected ? 0.7 : 1;
        } else {
            self.videoButton.selected=true;
            self.videoButton.alpha = self.videoButton.selected ? 0.7 : 1;
        }
    }
}

#pragma mark - Private

- (void)startPreview {
    // TVICameraCapturer is not supported with the Simulator.
    if ([PlatformUtils isSimulator]) {
        [self.previewView removeFromSuperview];
        return;
    }
    
    self.camera = [[TVICameraCapturer alloc] initWithSource:TVICameraCaptureSourceFrontCamera delegate:self];
    self.localVideoTrack = [TVILocalVideoTrack trackWithCapturer:self.camera
                                                         enabled:YES
                                                     constraints:nil
                                                            name:@"Camera"];
    if (!self.localVideoTrack) {
        [self logMessage:@"Failed to add video track"];
    } else {
        // Add renderer to video track for local preview
        [self.localVideoTrack addRenderer:self.previewView];
        
        [self logMessage:@"Video track created"];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(flipCamera)];
        [self.previewView addGestureRecognizer:tap];
    }
}

- (void)flipCamera {
    if (self.camera.source == TVICameraCaptureSourceFrontCamera) {
        [self.camera selectSource:TVICameraCaptureSourceBackCameraWide];
    } else {
        [self.camera selectSource:TVICameraCaptureSourceFrontCamera];
    }
}

- (void)prepareLocalMedia {
    
    // We will share local audio and video when we connect to room.
    
    // Create an audio track.
    if (!self.localAudioTrack) {
        self.localAudioTrack = [TVILocalAudioTrack trackWithOptions:nil
                                                            enabled:YES
                                                               name:@"Microphone"];
        
        if (!self.localAudioTrack) {
            [self logMessage:@"Failed to add audio track"];
        }
    }
    
    // Create a video track which captures from the camera.
    if (!self.localVideoTrack) {
        [self startPreview];
    }
}

- (void)doConnect:(NSString*)room withToken:(NSString *)accessToken {
    if ([accessToken isEqualToString:@""]) {
        [self logMessage:@"Please provide a valid token to connect to a room"];
        return;
    }
    // Prepare local media which we will share with Room Participants.
    if (![PlatformUtils isSimulator]) {
        [self prepareLocalMedia];
    }
    
    TVIConnectOptions *connectOptions = [TVIConnectOptions optionsWithToken:accessToken
                                                                      block:^(TVIConnectOptionsBuilder * _Nonnull builder) {
                                                                          
        // Use the local media that we prepared earlier.
        builder.audioTracks = self.localAudioTrack ? @[ self.localAudioTrack ] : @[ ];
        builder.videoTracks = self.localVideoTrack ? @[ self.localVideoTrack ] : @[ ];
        
        // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
        // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
        builder.roomName = room;
    }];
    
    // Connect to the Room using the options we provided.
    self.room = [TwilioVideo connectWithOptions:connectOptions delegate:self];
    
    [self logMessage:[NSString stringWithFormat:@"Attempting to connect to room %@", room]];
}

- (void)setupRemoteView {
    // Creating `TVIVideoView` programmatically
    TVIVideoView *remoteView = [[TVIVideoView alloc] init];
    
    // `TVIVideoView` supports UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFill and UIViewContentModeScaleAspectFit
    // UIViewContentModeScaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
    remoteView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self.view insertSubview:remoteView atIndex:0];
    self.remoteView = remoteView;
    
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1
                                                                constant:0];
//    [self.remoteView addConstraint:centerX];
    centerX.active = YES;
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1
                                                                constant:0];
//    [self.remoteView addConstraint:centerY];
    centerY.active = YES;
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:1
                                                              constant:0];
//    [self.remoteView addConstraint:width];
    width.active = YES;
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeHeight
                                                             multiplier:1
                                                               constant:0];
//    [self.remoteView addConstraint:height];
    height.active = YES;
}

// Reset the client ui status
- (void)showRoomUI:(BOOL)inRoom {
//    self.roomTextField.hidden = inRoom;
//    self.connectButton.hidden = inRoom;
//    self.roomLine.hidden = inRoom;
//    self.roomLabel.hidden = inRoom;
//    self.micButton.hidden = !inRoom;
//    self.disconnectButton.hidden = !inRoom;
    [UIApplication sharedApplication].idleTimerDisabled = inRoom;
}

- (void)cleanupRemoteParticipant {
    if (self.remoteParticipant) {
        if ([self.remoteParticipant.videoTracks count] > 0) {
            TVIRemoteVideoTrack *videoTrack = self.remoteParticipant.remoteVideoTracks[0].remoteTrack;
            [videoTrack removeRenderer:self.remoteView];
            [self.remoteView removeFromSuperview];
        }
        self.remoteParticipant = nil;
    }
}

- (void)logMessage:(NSString *)msg {
    NSLog(@"%@", msg);
    self.messageLabel.text = msg;
}

#pragma mark - UITextFieldDelegate
//
//- (BOOL)testFieldShouldReturn:(UITextField *)textField {
//    [self connectButtonPressed:textField];
//    return YES;
//}

#pragma mark - TVIRoomDelegate

- (void)didConnectToRoom:(TVIRoom *)room {
    // At the moment, this example only supports rendering one Participant at a time.
    
    [self logMessage:[NSString stringWithFormat:@"Connected to room %@ as %@", room.name, room.localParticipant.identity]];
    [self logMessage:@"Waiting on participant to join"];
    
    if (room.remoteParticipants.count > 0) {
        self.remoteParticipant = room.remoteParticipants[0];
        self.remoteParticipant.delegate = self;
        [self logMessage:@" "];
    }
}

- (void)room:(TVIRoom *)room didDisconnectWithError:(nullable NSError *)error {
    [self logMessage:[NSString stringWithFormat:@"Disconncted from room %@, error = %@", room.name, error]];
    
    [self cleanupRemoteParticipant];
    self.room = nil;
    
    [self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room didFailToConnectWithError:(nonnull NSError *)error{
    [self logMessage:[NSString stringWithFormat:@"Failed to connect to room, error = %@", error]];
    
    self.room = nil;
    
    [self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room participantDidConnect:(TVIRemoteParticipant *)participant {
    if (!self.remoteParticipant) {
        self.remoteParticipant = participant;
        self.remoteParticipant.delegate = self;
    }
    [self logMessage:[NSString stringWithFormat:@"Participant %@ connected with %lu audio and %lu video tracks",
                      participant.identity,
                      (unsigned long)[participant.audioTracks count],
                      (unsigned long)[participant.videoTracks count]]];
}

- (void)room:(TVIRoom *)room participantDidDisconnect:(TVIRemoteParticipant *)participant {
    if (self.remoteParticipant == participant) {
        [self cleanupRemoteParticipant];
    }
    [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ disconnected", room.name, participant.identity]];
}

#pragma mark - TVIParticipantDelegate

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      publishedVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    // Remote Participant has offered to share the video Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ video track .",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
    unpublishedVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the video Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      publishedAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    
    // Remote Participant has offered to share the audio Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
    unpublishedAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the audio Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      publishedDataTrack:(TVIRemoteDataTrackPublication *)publication {
    
    // Remote Participant has offered to share the data Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ data track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
    unpublishedDataTrack:(TVIRemoteDataTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the data Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ data track.",
                      participant.identity, publication.trackName]];
}
- (void)subscribedToVideoTrack:(TVIRemoteVideoTrack *)videoTrack
                   publication:(TVIRemoteVideoTrackPublication *)publication
                forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's video frames now.
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ video track for Participant %@",
                      publication.trackName, participant.identity]];
    
    if (self.remoteParticipant == participant) {
        [self setupRemoteView];
        [videoTrack addRenderer:self.remoteView];
    }
}

- (void)unsubscribedFromVideoTrack:(TVIRemoteVideoTrack *)videoTrack
                       publication:(TVIRemoteVideoTrackPublication *)publication
                    forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
    // remote Participant's video.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ video track for Participant %@",
                      publication.trackName, participant.identity]];
    
    if (self.remoteParticipant == participant) {
        [videoTrack removeRenderer:self.remoteView];
        [self.remoteView removeFromSuperview];
    }
}

- (void)subscribedToDataTrack:(TVIRemoteDataTrack *)dataTrack
                   publication:(TVIRemoteDataTrackPublication *)publication
                forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's data packets now.
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ data track for Participant %@",
                      publication.trackName, participant.identity]];
//
//    if (self.remoteParticipant == participant) {
//        [self setupRemoteView];
//        [videoTrack addRenderer:self.remoteView];
//    }
}

- (void)unsubscribedFromDataTrack:(TVIRemoteDataTrack *)dataTrack
                       publication:(TVIRemoteDataTrackPublication *)publication
                    forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's data Track. We will no longer receive the
    // remote Participant's data packets.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ data track for Participant %@",
                      publication.trackName, participant.identity]];
    
//    if (self.remoteParticipant == participant) {
//        [videoTrack removeRenderer:self.remoteView];
//        [self.remoteView removeFromSuperview];
//    }
}

- (void)subscribedToAudioTrack:(TVIRemoteAudioTrack *)audioTrack
                   publication:(TVIRemoteAudioTrackPublication *)publication
                forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's audio now.
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ audio track for Participant %@",
                      publication.trackName, participant.identity]];
}

- (void)unsubscribedFromAudioTrack:(TVIRemoteAudioTrack *)audioTrack
                       publication:(TVIRemoteAudioTrackPublication *)publication
                    forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
    // remote Participant's audio.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ audio track for Participant %@",
                      publication.trackName, participant.identity]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
        enabledVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
       disabledVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
        enabledAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
       disabledAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ audio track.",
                      participant.identity, publication.trackName]];
}

//- (void)participant:(TVIRemoteParticipant *)participant addedVideoTrack:(TVIVideoTrack *)videoTrack {
//    //   [self logMessage:[NSString stringWithFormat:@"Participant %@ added video track.", participant.identity]];
//
//    if (self.remoteParticipant == participant) {
//        [self setupRemoteView];
//        [videoTrack addRenderer:self.remoteView];
//    }
//}
//
//- (void)participant:(TVIRemoteParticipant *)participant removedVideoTrack:(TVIVideoTrack *)videoTrack {
//    //   [self logMessage:[NSString stringWithFormat:@"Participant %@ removed video track.", participant.identity]];
//
//    if (self.remoteParticipant == participant) {
//        [videoTrack removeRenderer:self.remoteView];
//        [self.remoteView removeFromSuperview];
//    }
//}
//
//- (void)participant:(TVIRemoteParticipant *)participant addedAudioTrack:(TVIAudioTrack *)audioTrack {
//    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ added audio track.", participant.identity]];
//}
//
//- (void)participant:(TVIRemoteParticipant *)participant removedAudioTrack:(TVIAudioTrack *)audioTrack {
//    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ removed audio track.", participant.identity]];
//}
//
//- (void)participant:(TVIRemoteParticipant *)participant enabledTrack:(TVITrack *)track {
//    NSString *type = @"";
//    if ([track isKindOfClass:[TVIAudioTrack class]]) {
//        type = @"audio";
//    } else {
//        type = @"video";
//    }
//    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ track.", participant.identity, type]];
//}
//
//- (void)participant:(TVIRemoteParticipant *)participant disabledTrack:(TVITrack *)track {
//    NSString *type = @"";
//    if ([track isKindOfClass:[TVIAudioTrack class]]) {
//        type = @"audio";
//    } else {
//        type = @"video";
//    }
//    //  [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ track.", participant.identity, type]];
//}

#pragma mark - TVIVideoViewDelegate

- (void)videoView:(TVIVideoView *)view videoDimensionsDidChange:(CMVideoDimensions)dimensions {
    NSLog(@"Dimensions changed to: %d x %d", dimensions.width, dimensions.height);
    [self.view setNeedsLayout];
}

#pragma mark - TVICameraCapturerDelegate

- (void)cameraCapturer:(TVICameraCapturer *)capturer didStartWithSource:(TVICameraCaptureSource)source {
    self.previewView.mirror = (source == TVICameraCaptureSourceFrontCamera);
}


@end
