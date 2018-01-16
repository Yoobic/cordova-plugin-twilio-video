/********* TwilioVideo.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import "TwilioVideoViewController.h"

@interface XXTwilioVideoPlugin : CDVPlugin

@end

@implementation XXTwilioVideoPlugin

- (void)openRoom:(CDVInvokedUrlCommand*)command {
    NSString* token = command.arguments[0];
    NSString* room = command.arguments[1];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"TwilioVideo" bundle:nil];
        XXTwilioVideoViewController *vc = [sb instantiateViewControllerWithIdentifier:@"XXTwilioVideoViewController"];

        // UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        // [vc.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissTwilioVideoController)]];

        [self.viewController presentViewController:vc animated:YES completion:^{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"ok"];
            [vc connectToRoom:room withToken:token];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    });

}

- (void) dismissTwilioVideoController {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
