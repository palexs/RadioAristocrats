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

class PageContentViewController: UIViewController {
    
    private let kAnnouncementDisplayOk = "Now On Air:"
    
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
        player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
        
        RadioManager.sharedInstance.fetchTrack(channel!) {
            (response: (track: Track?, message: String?), error: NSError?) -> Void in
            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                if let track = response.track {
                    print("Track: \(track.artist) \(track.title)")
                    strongSelf.trackTitleLabel.text = track.title
                    strongSelf.artistNameLabel.text = track.artist
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
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton) {
        print("Play button touched.")
        
        if (player?.rate == 0.0) {
            player?.play()
            playButton.setImage(UIImage(named: "pause"), forState: .Normal)
        } else {
            player?.pause()
            playButton.setImage(UIImage(named: "play"), forState: .Normal)
        }
    }
    
    @IBAction func indexChanged(sender: UISegmentedControl) {
        
        if let index = MusicQuality(rawValue: sender.selectedSegmentIndex) {
            
            player?.pause()
            playButton.setImage(UIImage(named: "play"), forState: .Normal)
            player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
            
            setupPlayer(channel!, quality: index)
            player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)

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
        playButton.setImage(UIImage(named: "play"), forState: .Normal)
        
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
    
}
