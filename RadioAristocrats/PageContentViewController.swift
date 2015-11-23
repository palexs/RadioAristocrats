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
    
    private struct Endpoint {
        static let MusicBestQualityUrl = "http://144.76.79.38:8000/live2"
        static let MusicGPRSUrl = "http://144.76.79.38:8000/live2-64"
    }
    
    private enum MusicQuality: Int {
        case Best = 0
        case GPRS = 1
    }
    
    private var KVOContext: UInt8 = 1
    private var player: AVPlayer?
    private var channel: RadioManager.ChannelType?

    var pageIndex: Int?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var musicQuialitySegmentedControl: UISegmentedControl!
    
    // MARK: - View Controller Lifecycle
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setupInitialUIAndPlayer()
        self.player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
        
        if let channel = RadioManager.ChannelType(rawValue: self.pageIndex!) {
            self.channel = channel
        } else {
            assertionFailure("*** Failed to set channel type!")
        }
        
        RadioManager.sharedInstance.fetchTrack(self.channel!) {
            (track: Track?, error: NSError?) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if let track = track {
                    print("Track: \(track.artist) \(track.title)")
                    self.trackTitleLabel.text = track.title
                    self.artistNameLabel.text = track.artist
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
        
        if let index = MusicQuality(rawValue : sender.selectedSegmentIndex) {
            
            self.player?.pause()
            self.playButton.setImage(UIImage(named: "play"), forState: .Normal)
            self.player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
            
            switch index {
            case .Best:
                self.setupPlayer(.Best)
                print("Best")
            case .GPRS:
                self.setupPlayer(.GPRS)
                print("GPRS")
            }
            
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
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Best.rawValue
                self.setupPlayer(.Best)
                print("Reachable via WiFi")
            } else {
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.GPRS.rawValue
                self.setupPlayer(.GPRS)
                print("Reachable via Cellular")
            }
        } else {
            print("*** Not reachable!")
        }
    }
    
    private func setupPlayer(quality: MusicQuality) -> Void {
        var url: NSURL?
        
        switch quality {
            case .Best:
                url = NSURL(string: Endpoint.MusicBestQualityUrl)
            case .GPRS:
                url = NSURL(string: Endpoint.MusicGPRSUrl)
        }
        
        let playerItem = AVPlayerItem(URL: url!)
        self.player = AVPlayer(playerItem: playerItem)
    }
    
}
