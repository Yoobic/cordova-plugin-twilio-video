//
//  AppDelegate.swift
//  DataTrackExample
//
//  Copyright © 2017 Twilio. All rights reserved.
//

import Foundation
import TwilioVideo
import UIKit

@objc(HWTwilioVideoPlugin)
class TwilioVideoPlugin : CDVPlugin {
	/**
	 Show a native view from a cordova app.
	 If exists a navigationController associated with your cordova
	 UIViewController, back to your main view.
	 
	 - Parameters:
	 - command: Get arguments and callback status from JS
	 */
	func openRoom(command: CDVInvokedUrlCommand) {
	  let token = command.arguments[0]
	  let room = command.arguments[1]

	  dispatch_async(dispatch_get_main_queue(), {
		  let sb = UIStoryboard(name: "TwilioVideo", bundle: nil)
		  let vc = sb.instantiateViewController(withIdentifier: "TwilioVideoViewController") as UIViewController
		  
		  vc.accessToken = token
		  let nav = UINavigationController(rootViewController: vc)
		  vc.navigationItem.rightBarButtonItem = UIBarButtonItem(
			  barButtonSystemItem: UIBarButtonSystemItemDone,
			  target: self,
			  action: dismissTwilioVideoController
		  )
			
		  
		  
		  self.viewController.presentViewController(
				_ viewControllerToPresent: nav,
				animated: true,
				completion: {
					(errors: [[String:String]]?) -> Void in
                
					dispatch_async(dispatch_get_main_queue()) {
							var pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
							if (errors != nil) {
									pluginResult = CDVPluginResult(
											status: CDVCommandStatus_ERROR,
											messageAsDictionary: errors!.first
									)
							}
							self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId)
					}
					let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString:"ok")
					vc.connectToRoom(room)
					self.commandDelegate!.sendPluginResult:pluginResult callbackId:command.callbackId];
				}
			);
	  });

		dismissTwilioVideoController {
			self.viewController.dismiss(animated: true, completion: nil);
		}

	}

}

