//
//  PlayerManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 12/10/15.
//  Copyright © 2015 RadioAristocrats. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

let kViewControllerRemotePlayPauseCommandNotification = "RemotePlayPauseCommandReceivedNotification"
let kViewControllerUpdatePlayButtonNotification = "UpdatePlayButtonNotification"

class PlayerManager: NSObject, PageContentViewControllerDelegate {
    
//    private var KVOContext: UInt8 = 1
    private var _player: AVPlayer
    private var _channel: ChannelType
    private var _quality: MusicQuality
    
    override init() {
        // Create player with default settings
        _channel = .Stream
        _quality = .Best
        let url = NSURL(string: RadioManager.endpointUrlString(_channel, quality: _quality))
        let playerItem = AVPlayerItem(URL: url!)
        _player = AVPlayer(playerItem: playerItem)
        
        super.init()
        
        // Setup background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                print("AVAudioSession Category Playback Ok and AVAudioSession is set to active.")
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_handleAudioSessionInterruption:", name: AVAudioSessionInterruptionNotification, object: nil)
        
        // Setup Remote Command Center
        MPRemoteCommandCenter.sharedCommandCenter().playCommand.addTarget(self, action: "p_remotePlayCommandReceived")
        MPRemoteCommandCenter.sharedCommandCenter().pauseCommand.addTarget(self, action: "p_remotePauseCommandReceived")
        MPRemoteCommandCenter.sharedCommandCenter().playCommand.enabled = true
        MPRemoteCommandCenter.sharedCommandCenter().pauseCommand.enabled = true
        MPRemoteCommandCenter.sharedCommandCenter().previousTrackCommand.enabled = false
        MPRemoteCommandCenter.sharedCommandCenter().nextTrackCommand.enabled = false
        MPRemoteCommandCenter.sharedCommandCenter().seekBackwardCommand.enabled = false
        MPRemoteCommandCenter.sharedCommandCenter().seekForwardCommand.enabled = false
    }
    
    // MARK: - Public API
    
    var channel: ChannelType { get { return _channel} }
    var quality: MusicQuality { get { return _quality} }

    class var sharedPlayer: PlayerManager {
        struct Static {
            static let instance: PlayerManager = PlayerManager()
        }
        return Static.instance
    }
    
    func updatePlayerForState(state: State) -> Void {
        let url = NSURL(string: RadioManager.endpointUrlString(state.channel, quality: state.quality))
        let playerItem = AVPlayerItem(URL: url!)
//            _player.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
//            _player.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
        _player.replaceCurrentItemWithPlayerItem(playerItem)
        _channel = state.channel
        _quality = state.quality
    }
    
    func play() -> Void {
        _player.play()
    }
    
    func pause() -> Void {
        _player.pause()
    }
    
    func isPaused() -> Bool {
        return _player.rate == 0.0
    }
    
    // MARK: - PageContentViewController Delegate
    
    func pageContentViewController(controller: PageContentViewController, didRecievePlayButtonTapWithState state: State) -> Void {
        if (state.channel == PlayerManager.sharedPlayer.channel) {
            if (PlayerManager.sharedPlayer.isPaused()) {
                PlayerManager.sharedPlayer.play()
            } else {
                PlayerManager.sharedPlayer.pause()
            }
        } else {
            PlayerManager.sharedPlayer.updatePlayerForState(state)
            PlayerManager.sharedPlayer.play()
        }
    }
    
    func pageContentViewController(controller: PageContentViewController, didRecieveMusicQualitySwitchWithState state: State) -> Void {
        if (state.channel == PlayerManager.sharedPlayer.channel) {
            if (!PlayerManager.sharedPlayer.isPaused()) {
                PlayerManager.sharedPlayer.updatePlayerForState(state)
                PlayerManager.sharedPlayer.play()
            }
            
        }
    }
    
    // MARK: - Remote Command Center handlers
    
    func p_remotePlayCommandReceived() -> MPRemoteCommandHandlerStatus {
        play()
        NSNotificationCenter.defaultCenter().postNotificationName(kViewControllerRemotePlayPauseCommandNotification, object: self)
        return .Success
    }
    
    func p_remotePauseCommandReceived() -> MPRemoteCommandHandlerStatus {
        pause()
        NSNotificationCenter.defaultCenter().postNotificationName(kViewControllerRemotePlayPauseCommandNotification, object: self)
        return .Success
    }
    
    // MARK: - Notification Handlers
    
    func p_handleAudioSessionInterruption(notification: NSNotification) -> Void {
        guard let typeKey = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            else { return }
        guard let type = AVAudioSessionInterruptionType(rawValue: typeKey)
            else { return }
        
        switch type {
        case .Began:
            print("AVAudioSession interruption began.")
        case .Ended:
//            _ = try? AVAudioSession.sharedInstance().setActive(true, withOptions: [])
//            _player.play()
            print("AVAudioSession interruption ended.")
            NSNotificationCenter.defaultCenter().postNotificationName(kViewControllerUpdatePlayButtonNotification, object: nil)
        }
    }
    
    // MARK: - KVO
    
//    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
//        if (context == &KVOContext) {
//            //            var playerItem = object as! AVPlayerItem
//        } else {
//            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
//        }
//    }

}
