//
//  TwilioVideoViewController.h
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

@import UIKit;

@interface TwilioVideoViewController : UIViewController

- (void)connectToRoom:(NSString*)room withToken:(NSString*)accessToken;

@end
