//
//  ViewController.swift
//  VideoQuickStart
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

import UIKit

import TwilioVideo

@objc(TwilioVideoViewController)
class TwilioVideoViewController: UIViewController {

    // MARK: View Controller Members
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    // at https://www.twilio.com/console/video/runtime/testing-tools
  
    // Configure remote URL to fetch token from
//     var tokenUrl = "http://yoobic-loopback-dev-v3-/token.php"
    
    // Video SDK components
    var room: TVIRoom?
    var camera: TVICameraCapturer?
    var localVideoTrack: TVILocalVideoTrack?
    var localAudioTrack: TVILocalAudioTrack?
    var remoteParticipant: TVIRemoteParticipant?
    var remoteView: TVIVideoView?
    
    var delegate: TwilioVideoViewControllerDelegate?
    
    weak var previewTapToFlip: UIGestureRecognizer?

    // MARK: UI Element Outlets and handles
    
    // `TVIVideoView` created from a storyboard
    @IBOutlet weak var previewView: TVIVideoView!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var recordingLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var flipCameraButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!

    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "YOOBIC Connect"
        self.messageLabel.adjustsFontSizeToFitWidth = true;
        self.messageLabel.minimumScaleFactor = 0.75;

        if PlatformUtils.isSimulator {
            self.previewView.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        // Disconnect and mic button will be displayed when the Client is connected to a Room.
        self.recordingLabel.isHidden = true
        self.recordingLabel.isEnabled = false
    }
    
    func setupRemoteVideoView() {
        // Creating `TVIVideoView` programmatically
        self.remoteView = TVIVideoView(frame: CGRect.zero, delegate:self)
        
        self.view.insertSubview(self.remoteView!, at: 0)
        
        // `TVIVideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
        self.remoteView!.contentMode = .scaleAspectFit;

        let centerX = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutAttribute.centerX,
                                         relatedBy: NSLayoutRelation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutAttribute.centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutAttribute.centerY,
                                         relatedBy: NSLayoutRelation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutAttribute.centerY,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: self.remoteView!,
                                       attribute: NSLayoutAttribute.width,
                                       relatedBy: NSLayoutRelation.equal,
                                       toItem: self.view,
                                       attribute: NSLayoutAttribute.width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: self.remoteView!,
                                        attribute: NSLayoutAttribute.height,
                                        relatedBy: NSLayoutRelation.equal,
                                        toItem: self.view,
                                        attribute: NSLayoutAttribute.height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
    }

    func connect(roomName: String, accessToken: String) {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
//        if (accessToken == "TWILIO_ACCESS_TOKEN") {
//            do {
//                accessToken = try TokenUtils.fetchToken(url: tokenUrl)
//            } catch {
//                let message = "Failed to fetch access token"
//                logMessage(messageText: message)
//                return
//            }
//        }
        
        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()
        
        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions: TVIConnectOptions = TVIConnectOptions.init(token: accessToken, block: {(builder) in
            
            // Use the local media that we prepared earlier.
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [TVILocalAudioTrack]()
            builder.videoTracks = self.localVideoTrack != nil ? [self.localVideoTrack!] : [TVILocalVideoTrack]()
            
            // Use the preferred audio codec
            if let preferredAudioCodec = Settings.shared.audioCodec {
                builder.preferredAudioCodecs = [preferredAudioCodec.rawValue]
            }
            
            // Use the preferred video codec
            if let preferredVideoCodec = Settings.shared.videoCodec {
                builder.preferredVideoCodecs = [preferredVideoCodec.rawValue]
            }
            
            // Use the preferred encoding parameters
            if let encodingParameters = Settings.shared.getEncodingParameters() {
                builder.encodingParameters = encodingParameters
            }
            
            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = roomName
        })
        
        // Connect to the Room using the options we provided.
        room = TwilioVideo.connect(with: connectOptions, delegate: self)

        logMessage(messageText: "Attempting to connect to room \(String(describing: room))")
        
        self.showRoomUI(inRoom: true)
    }

    func disconnect() {
        self.room!.disconnect()
        logMessage(messageText: "Attempting to disconnect from room \(room!.name)")
    }

    // MARK: IBActions
    @IBAction func disconnect(sender: AnyObject) {
        self.disconnect()
    }
    
    @IBAction func toggleMic(sender: AnyObject) {
        if (self.localAudioTrack != nil) {
            self.localAudioTrack?.isEnabled = !(self.localAudioTrack?.isEnabled)!
            
            // Update the button title
            if (self.localAudioTrack?.isEnabled == true) {
                self.micButton.setTitle("Mute", for: .normal)
            } else {
                self.micButton.setTitle("Unmute", for: .normal)
            }
        }
    }

    @IBAction func toggleVideo(sender: AnyObject) {
        if (self.localVideoTrack != nil) {
            self.localVideoTrack?.isEnabled = !(self.localVideoTrack?.isEnabled)!
            
            // Update the button title
            if (self.localVideoTrack?.isEnabled == true) {
                self.videoButton.setTitle("Pause", for: .normal)
            } else {
                self.videoButton.setTitle("Play", for: .normal)
            }
        }
    }
    
    @IBAction func flipCamera(sender: AnyObject) {
        flipCamera();
    }

    // MARK: Private
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }

        // Preview our local camera track in the local video preview view.
        camera = TVICameraCapturer(source: .frontCamera, delegate: self)
        localVideoTrack = TVILocalVideoTrack.init(capturer: camera!, enabled: true, constraints: nil, name: "Camera")
        if (localVideoTrack == nil) {
            logMessage(messageText: "Failed to create video track")
        } else {
            // Add renderer to video track for local preview
            localVideoTrack!.addRenderer(self.previewView)

            logMessage(messageText: "Video track created")

            // We will flip camera on tap.
//            previewTapToFlip = UITapGestureRecognizer(target: self, action: #selector(TwilioVideoViewController.flipCamera as (TwilioVideoViewController) -> () -> ()))
//            self.previewView.addGestureRecognizer(previewTapToFlip!)
        }
    }

    func stopPreview() {
        if PlatformUtils.isSimulator {
            return
        }

        if (localVideoTrack == nil) {
            logMessage(messageText: "No local video track to clean up")
        } else {
            // Add renderer to video track for local preview
            localVideoTrack!.removeRenderer(self.previewView)

            logMessage(messageText: "Video track removed")
            self.previewView?.removeFromSuperview()
            if previewTapToFlip != nil {
                self.previewView.removeGestureRecognizer(previewTapToFlip!)
            }
            self.previewView = nil
        }
    }

    func flipCamera() {
        if (self.camera?.source == .frontCamera) {
            self.camera?.selectSource(.backCameraWide)
        } else {
            self.camera?.selectSource(.frontCamera)
        }
    }

    func prepareLocalMedia() {
        // We will share local audio and video when we connect to the Room.

        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = TVILocalAudioTrack(options: nil, enabled: true, name: "Microphone")

            if (localAudioTrack == nil) {
                logMessage(messageText: "Failed to create audio track")
            }
        }

        // Create a video track which captures from the camera.
        if (localVideoTrack == nil) {
            self.startPreview()
        }
   }

    // Update our UI based upon if we are in a Room or not
    func showRoomUI(inRoom: Bool) {
        self.navigationController?.setNavigationBarHidden(inRoom, animated: true)
        UIApplication.shared.isIdleTimerDisabled = inRoom
    }

    func cleanupRoomUI() {
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        UIApplication.shared.isIdleTimerDisabled = false
        delegate?.closeAfterDisconnect()
    }

    func toggleRecordingState() {
        toggleRecordingState(isRecording: room?.isRecording ?? false)
    }

    func toggleRecordingState(isRecording: Bool) {
        self.recordingLabel.isHidden = !isRecording
        self.recordingLabel.isEnabled = isRecording
        self.recordingLabel.isHighlighted = isRecording
    }
    
    func cleanupRemoteParticipant(videoTrack: TVIRemoteVideoTrack?) {
        if self.remoteView != nil {
            videoTrack?.removeRenderer(self.remoteView!)
        }
        self.remoteView?.removeFromSuperview()
        self.remoteView = nil
    }
    
    func cleanupRemoteParticipant() {
        if ((self.remoteParticipant) != nil) {
            if ((self.remoteParticipant?.videoTracks.count)! > 0) {
                let remoteVideoTrack = self.remoteParticipant?.remoteVideoTracks[0].remoteTrack
                cleanupRemoteParticipant(videoTrack: remoteVideoTrack)
            }
        }
        self.remoteParticipant = nil
    }

    func logMessage(messageText: String) {
        messageLabel.text = messageText
    }
}

// MARK: UITextFieldDelegate
//extension ViewController : UITextFieldDelegate {
//    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        self.connect(sender: textField)
//        return true
//    }
//}

// MARK: TVIRoomDelegate
extension TwilioVideoViewController : TVIRoomDelegate {
    func didConnect(to room: TVIRoom) {
        
        if (room.isRecording) {
            toggleRecordingState(isRecording: true)
        } else {
            toggleRecordingState(isRecording: false)
        }
        
        // At the moment, this example only supports rendering one Participant at a time.
        logMessage(messageText: "Connected to room \(room.name) as \(String(describing: room.localParticipant?.identity))")
        
        if (room.remoteParticipants.count > 0) {
            self.remoteParticipant = room.remoteParticipants[0]
            self.remoteParticipant?.delegate = self
        }
    }
    
    func room(_ room: TVIRoom, didDisconnectWithError error: Error?) {
        logMessage(messageText: "Disconncted from room \(room.name), error = \(String(describing: error))")
        
        self.cleanupRemoteParticipant()
        self.room = nil
        
        self.cleanupRoomUI()
    }
    
    func room(_ room: TVIRoom, didFailToConnectWithError error: Error) {
        logMessage(messageText: "Failed to connect to room with error")
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func room(_ room: TVIRoom, participantDidConnect participant: TVIRemoteParticipant) {
        if (self.remoteParticipant == nil) {
            self.remoteParticipant = participant
            self.remoteParticipant?.delegate = self
        }
        logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }
    
    func room(_ room: TVIRoom, participantDidDisconnect participant: TVIRemoteParticipant) {
        if (self.remoteParticipant == participant) {
            cleanupRemoteParticipant()
        }
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")
    }
    
    func roomDidStartRecording(_ room: TVIRoom) {
        toggleRecordingState(isRecording: true)
    }
    
    func roomDidStopRecording(_ room: TVIRoom) {
        toggleRecordingState(isRecording: false)
    }
}

// MARK: TVIRemoteParticipantDelegate
extension TwilioVideoViewController : TVIRemoteParticipantDelegate {
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           publishedVideoTrack publication: TVIRemoteVideoTrackPublication) {
        
        // Remote Participant has offered to share the video Track.
        
        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           unpublishedVideoTrack publication: TVIRemoteVideoTrackPublication) {
        
        // Remote Participant has stopped sharing the video Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           publishedAudioTrack publication: TVIRemoteAudioTrackPublication) {
        
        // Remote Participant has offered to share the audio Track.

        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           unpublishedAudioTrack publication: TVIRemoteAudioTrackPublication) {
        
        // Remote Participant has stopped sharing the audio Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

   func subscribed(to videoTrack: TVIRemoteVideoTrack,
                    publication: TVIRemoteVideoTrackPublication,
                    for participant: TVIRemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's video frames now.
        
        logMessage(messageText: "Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == participant) {
            setupRemoteVideoView()
            videoTrack.addRenderer(self.remoteView!)
        }
    }
    
    func unsubscribed(from videoTrack: TVIRemoteVideoTrack,
                      publication: TVIRemoteVideoTrackPublication,
                      for participant: TVIRemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == participant) {
            cleanupRemoteParticipant(videoTrack: videoTrack)
        }
    }
    
    func subscribed(to audioTrack: TVIRemoteAudioTrack,
                    publication: TVIRemoteAudioTrackPublication,
                    for participant: TVIRemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
       
        logMessage(messageText: "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func unsubscribed(from audioTrack: TVIRemoteAudioTrack,
                      publication: TVIRemoteAudioTrackPublication,
                      for participant: TVIRemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
   func remoteParticipant(_ participant: TVIRemoteParticipant,
                           enabledVideoTrack publication: TVIRemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           disabledVideoTrack publication: TVIRemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           enabledAudioTrack publication: TVIRemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           disabledAudioTrack publication: TVIRemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func failedToSubscribe(toAudioTrack publication: TVIRemoteAudioTrackPublication,
                           error: Error,
                           for participant: TVIRemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func failedToSubscribe(toVideoTrack publication: TVIRemoteVideoTrackPublication,
                           error: Error,
                           for participant: TVIRemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK: TVIVideoViewDelegate
extension TwilioVideoViewController : TVIVideoViewDelegate {
    func videoView(_ view: TVIVideoView, videoDimensionsDidChange dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK: TVICameraCapturerDelegate
extension TwilioVideoViewController : TVICameraCapturerDelegate {
    func cameraCapturer(_ capturer: TVICameraCapturer, didStartWith source: TVICameraCaptureSource) {
        self.previewView.shouldMirror = (source == .frontCamera)
    }
}

// MARK: TwilioVideoViewControllerDelegate
protocol TwilioVideoViewControllerDelegate: class {
    func closeAfterDisconnect()
}
