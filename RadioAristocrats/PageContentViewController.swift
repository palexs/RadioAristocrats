//
//  PageContentViewController.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import UIKit
import AVFoundation
import ReachabilitySwift
import MediaPlayer

class PageContentViewController: UIViewController {
    
    private let kAnnouncementDisplayOk = "Now On Air:"
    private let kDefaultStreamColor = UIColor(red: 212/255, green: 68/255, blue: 79/255, alpha: 1.0) // #D4444F
    private let kDefaultAMusicColor = UIColor(red: 0/255, green: 48/255, blue: 74/255, alpha: 1.0) // #00304A
    private let kDefaultJazzColor = UIColor(red: 212/255, green: 68/255, blue: 79/255, alpha: 1.0) // #D4444F
    
    private var KVOContext: UInt8 = 1
    private var player: AVPlayer?
    private var channel: ChannelType?
    
    var pageIndex: Int?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var musicQuialitySegmentedControl: UISegmentedControl!
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        if let aChannel = ChannelType(rawValue: pageIndex!) {
            channel = aChannel
        } else {
            assertionFailure("*** Failed to set channel type!")
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setupInitialUIAndPlayer()
        setupDefaultColors()
        
        player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
        NSNotificationCenter.defaultCenter().addObserverForName(ViewControllerRemotePlayPauseCommandReceivedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [weak self] (notif) -> Void in
            guard let strongSelf = self else { return }
            // Redirect
            strongSelf.playButtonTouched(nil)
        }

        RadioManager.sharedInstance.fetchTrack(channel!) {
            (response: (track: Track?, message: String?), error: NSError?) -> Void in
            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                
                // Set default now playing info
                let defaultAlbumArtWork = MPMediaItemArtwork(image: UIImage(named: "default_artwork")!)
                var songInfo: [String: AnyObject] = [
                    MPMediaItemPropertyTitle: "Unknown Title",
                    MPMediaItemPropertyArtist: "Unknown Artist",
                    MPMediaItemPropertyArtwork: defaultAlbumArtWork,
                    MPMediaItemPropertyPlaybackDuration: NSNumber(integer: 0)
                ]
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
                
                if let track = response.track {
                    print("Track: \(track.artist) \(track.title)")
                    
                    if let title = track.title {
                        if !title.isEmpty {
                            strongSelf.trackTitleLabel.text = title
                            songInfo[MPMediaItemPropertyTitle] = title
                        }
                    }
                    
                    if let artist = track.artist {
                        if !artist.isEmpty {
                            strongSelf.artistNameLabel.text = artist
                            songInfo[MPMediaItemPropertyArtist] = artist
                            
                            // Fetch and update artwork
                            RadioManager.sharedInstance.fetchArtwork(artist, callback: {
                                (image: UIImage?, error: NSError?) -> Void in
                                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                    if (error != nil) {
                                        print("*** Failed to fetch an artwork for \(track)! Details: \(error)")
                                    }
                                    
                                    if let img = image {
                                        songInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: img)
                                        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
                                    }
                                })
                            })
                        }
                    }
                    
                }
                
                if let message = response.message {
                    if !message.containsString(strongSelf.kAnnouncementDisplayOk) {
                        print("*** Couldn't extract track information!")
                        strongSelf.trackTitleLabel.text = "Oops, something went wrong!"
                        strongSelf.artistNameLabel.text = message
                    }
                }
            })
        }
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        player?.pause()
        player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ViewControllerRemotePlayPauseCommandReceivedNotification, object: nil)
        player = nil
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton?) {
        print("Play button touched.")
        
        updatePlayButton()
        
        if (player?.rate == 0.0) {
            player?.play()
        } else {
            player?.pause()
        }
        
    }
    
    @IBAction func indexChanged(sender: UISegmentedControl) {
        
        if let index = MusicQuality(rawValue: sender.selectedSegmentIndex) {
            
            let wasPlaying = player?.rate != 0.0
            
            player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
            setupPlayer(channel!, quality: index)
            player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
            
            if (wasPlaying) {
                player?.play()
            }

        } else {
            assertionFailure("*** Invalid segmented control index!")
        }
    }
    
    // MARK: - KVO
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if (context == &KVOContext) {
//            var playerItem = object as! AVPlayerItem
            
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: - Private methods
    
    private func setupInitialUIAndPlayer() -> Void {

        updatePlayButton()
        
        let reachability: Reachability?
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch _ {
            print("*** Failed to obtain reachability value!")
            reachability = nil
        }
        
        if reachability!.isReachable() {
            if reachability!.isReachableViaWiFi() {
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Best.rawValue
                setupPlayer(channel!, quality: MusicQuality.Best)
                print("Reachable via WiFi")
            } else {
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Edge.rawValue
                setupPlayer(channel!, quality: MusicQuality.Edge)
                print("Reachable via Cellular")
            }
        } else {
            print("*** Not reachable!")
        }
    }
    
    private func setupPlayer(channel: ChannelType, quality: MusicQuality) -> Void {
        let url = NSURL(string: RadioManager.endpointUrlString(channel, quality: quality))
        let playerItem = AVPlayerItem(URL: url!)
        player = AVPlayer(playerItem: playerItem)
    }
    
    private func updatePlayButton() {
        var image: UIImage?
        
        if (player != nil && player?.rate == 0.0) {
            switch channel! {
                case .Stream, .Jazz:
                    image = UIImage(named: "pause")
                case .AMusic:
                    image = UIImage(named: "pause_a")
            }
        } else {
            switch channel! {
            case .Stream, .Jazz:
                image = UIImage(named: "play")
            case .AMusic:
                image = UIImage(named: "play_a")
            }
        }
        
        playButton.setImage(image, forState: .Normal)
    }
    
    private func setupDefaultColors() {
        switch channel! {
            case .Stream:
                musicQuialitySegmentedControl.tintColor = kDefaultStreamColor
            case .AMusic:
                musicQuialitySegmentedControl.tintColor = kDefaultAMusicColor
            case .Jazz:
                musicQuialitySegmentedControl.tintColor = kDefaultJazzColor
        }
    }
    
}
