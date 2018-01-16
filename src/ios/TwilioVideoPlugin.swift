/********* TwilioVideoPlugin.swift Cordova Plugin Implementation *******/

import Foundation
import TwilioVideo
import UIKit

@objc(TwilioVideoPlugin)
class TwilioVideoPlugin: CDVPlugin {
    var vc: TwilioVideoViewController?
    var sb: UIStoryboard?
    func openRoom(_ command: CDVInvokedUrlCommand) {
        let token: String = command.argument(at: 0, withDefault: "") as! String
        let room: String = command.argument(at: 1, withDefault: "") as! String
        self.commandDelegate.run(inBackground: {
            DispatchQueue.main.async(execute: {() -> Void in
                self.sb = UIStoryboard(name: "TwilioVideoSwift", bundle: nil)
                self.vc = self.sb!.instantiateViewController(withIdentifier: "TwilioVideoViewController") as? TwilioVideoViewController
                self.vc?.delegate = self
                self.viewController.present(self.vc!, animated: true, completion: {() -> Void in
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "ok")
                    self.vc!.connect(roomName: room, accessToken: token)
                    self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                })
            })
        })
    }
    
    override func onReset() {
        
    }
    
    func closeRoom(_ command: CDVInvokedUrlCommand) {
        if vc != nil  {
            vc!.disconnect()
        }
        dismissTwilioVideoController()
    }
    
    
    func dismissTwilioVideoController() {
       viewController.dismiss(animated: true) {() -> Void in }
    }
}

extension TwilioVideoPlugin : TwilioVideoViewControllerDelegate {
    func closeAfterDisconnect() {
        self.dismissTwilioVideoController()
    }
}
