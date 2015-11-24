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
    
    private var KVOContext: UInt8 = 1
    private var player: AVPlayer?
    private var channel: RadioManager.ChannelType?
    private var quality: RadioManager.MusicQuality?
    
    var pageIndex: Int?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var musicQuialitySegmentedControl: UISegmentedControl!
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        if let channel = RadioManager.ChannelType(rawValue: self.pageIndex!) {
            self.channel = channel
        } else {
            assertionFailure("*** Failed to set channel type!")
        }
        
        if let quality = RadioManager.MusicQuality(rawValue: self.musicQuialitySegmentedControl.selectedSegmentIndex) {
            self.quality = quality
        } else {
            assertionFailure("*** Failed to set music quality!")
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setupInitialUIAndPlayer()
        self.player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
        
        RadioManager.sharedInstance.fetchTrack(self.channel!) {
            (response: (track: Track?, message: String?), error: NSError?) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if let track = response.track {
                    print("Track: \(track.artist) \(track.title)")
                    self.trackTitleLabel.text = track.title
                    self.artistNameLabel.text = track.artist
                }
                
                if let message = response.message {
                    if !message.containsString("Now On Air:") {
                        print("*** Couldn't extract track information!")
                        self.trackTitleLabel.text = "Oops, something went wrong!"
                        self.artistNameLabel.text = message
                    }
                }
            })
        }
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.player?.pause()
        self.player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton) {
        print("Play button touched.")
        
        if (self.player?.rate == 0.0) {
            self.player?.play()
            self.playButton.setImage(UIImage(named: "pause"), forState: .Normal)
        } else {
            self.player?.pause()
            self.playButton.setImage(UIImage(named: "play"), forState: .Normal)
        }
    }
    
    @IBAction func indexChanged(sender: UISegmentedControl) {
        
        if let index = RadioManager.MusicQuality(rawValue: sender.selectedSegmentIndex) {
            
            self.player?.pause()
            self.playButton.setImage(UIImage(named: "play"), forState: .Normal)
            self.player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
            
            self.setupPlayer(self.channel!, quality: index)
            self.player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)

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
        self.playButton.setImage(UIImage(named: "play"), forState: .Normal)
        
        let reachability: Reachability?
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch _ {
            print("*** Failed to obtain reachability value!")
            reachability = nil
        }
        
        if reachability!.isReachable() {
            if reachability!.isReachableViaWiFi() {
                musicQuialitySegmentedControl.selectedSegmentIndex = RadioManager.MusicQuality.Best.rawValue
                self.setupPlayer(self.channel!, quality: RadioManager.MusicQuality.Best)
                print("Reachable via WiFi")
            } else {
                musicQuialitySegmentedControl.selectedSegmentIndex = RadioManager.MusicQuality.Edge.rawValue
                self.setupPlayer(self.channel!, quality: RadioManager.MusicQuality.Edge)
                print("Reachable via Cellular")
            }
        } else {
            print("*** Not reachable!")
        }
    }
    
    private func setupPlayer(channel: RadioManager.ChannelType, quality: RadioManager.MusicQuality) -> Void {
        let url = NSURL(string: RadioManager.Endpoint.Music(channel, quality).urlString())
        let playerItem = AVPlayerItem(URL: url!)
        self.player = AVPlayer(playerItem: playerItem)
    }
    
}
