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
    
//    private var kKVOContext: UInt8 = 1
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
        super.init() // super.init() must be called AFTER you initialize all your instance variables
//        _player.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &kKVOContext)
        
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
//        _player.currentItem!.removeObserver(self, forKeyPath: "status", context: &kKVOContext)
        let url = NSURL(string: RadioManager.endpointUrlString(state.channel, quality: state.quality))
        let playerItem = AVPlayerItem(URL: url!)
        _player.replaceCurrentItemWithPlayerItem(playerItem)
//        _player.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &kKVOContext)
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
    
    func updateSongInfo() -> Void {
        p_fetchTrackAndArtwork()
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
    
    private func p_updateSongInfoWithTrack(track: Track, artwork: UIImage?) -> Void {
        var artworkImage: UIImage
        if let artwork = artwork {
            artworkImage = artwork
        } else {
            artworkImage = UIImage(named: "default_artwork")!
        }
        
        // On Air - no artist and track info
        if (track.title == kTrackEmptyString || track.artist == kTrackEmptyString) {
            track.title = LocalizableString.OnAir.localizedText(LocalizableString.isTodayThursday())
            track.artist = " "
        }
        
        // No Internet connection
        if (ReachabilityManager.sharedManager.isInternetConnectionAvailable() == false) {
            track.title = LocalizableString.Error.localizedText(LocalizableString.isTodayThursday())
            track.artist = LocalizableString.NoInternetConnection.localizedText(LocalizableString.isTodayThursday())
        }
        
        let songInfo: [String: AnyObject] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: artworkImage),
            MPMediaItemPropertyPlaybackDuration: NSNumber(integer: 0)
        ]
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
    }
    
    private func p_updateSongInfoWithError(error: RadioManagerError) -> Void {
        let errorTitle = LocalizableString.NoTrackInfoErrorMessage.localizedText(LocalizableString.isTodayThursday())
        let errorArtist = error.toString()
        let errorTrack = Track(title: errorTitle, artist: errorArtist)
        self.p_updateSongInfoWithTrack(errorTrack, artwork:nil)
    }
    
    private func p_fetchTrackAndArtwork() -> Void {
        RadioManager.sharedInstance.fetchTrack(_channel) {
            (result: Result<Track>) -> Void in
                switch result {
                case .Success(let track):
                    // Fetch and update artwork
                    RadioManager.sharedInstance.fetchArtwork(track.artist) { [unowned self]
                        (result: Result<UIImage>) -> Void in
                            switch result {
                            case .Success(let image):
                                self.p_updateSongInfoWithTrack(track, artwork:image)
                            case .Failure(let error):
                                self.p_updateSongInfoWithError(error)
                            }
                        
                    }
                case .Failure(let error):
                    switch error {
                    case .FailedToObtainTrackInfo:
                        let unknownTitle = LocalizableString.UnknownTrack.localizedText(LocalizableString.isTodayThursday())
                        let unknownArtist = LocalizableString.UnknownArtist.localizedText(LocalizableString.isTodayThursday())
                        let unknownTrack = Track(title: unknownTitle, artist: unknownArtist)
                        self.p_updateSongInfoWithTrack(unknownTrack, artwork:nil)
                    default:
                        self.p_updateSongInfoWithError(error)
                    }

                }
            }
    }
    
    // MARK: - KVO
    
//    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
//        if (context == &kKVOContext) {
//            //            var playerItem = object as! AVPlayerItem
//        } else {
//            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
//        }
//    }

}
