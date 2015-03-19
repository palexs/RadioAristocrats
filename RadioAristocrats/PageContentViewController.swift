//
//  PageContentViewController.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import UIKit
import AVFoundation

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

    var pageIndex: Int?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var musicQuialitySegmentedControl: UISegmentedControl!
    
    // MARK: - View Controller Lifecycle
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setupInitialUIAndPlayer()
        
        self.player?.currentItem.addObserver(self, forKeyPath: "status", options: .allZeros, context: &KVOContext)
        
        RadioManager.sharedInstance.fetchCurrentTrack {
            (track: Track?, error: NSError?) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if let track = track {
                    println("Track: \(track.artist) \(track.title)")
                    self.trackTitleLabel.text = track.title
                    self.artistNameLabel.text = track.artist
                }
            })
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.player?.pause()
        self.player?.currentItem.removeObserver(self, forKeyPath: "status", context: &KVOContext)
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton) {
        println("Play button touched.")
        
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
            self.player?.currentItem.removeObserver(self, forKeyPath: "status", context: &KVOContext)
            
            switch index {
            case .Best:
                self.setupPlayer(.Best)
                println("Best")
            case .GPRS:
                self.setupPlayer(.GPRS)
                println("GPRS")
            default:
                break
            }
            
            self.player?.currentItem.addObserver(self, forKeyPath: "status", options: .allZeros, context: &KVOContext)

        } else {
            println("*** Invalid segmented control index!")
        }
    }
    
    // MARK: - KVO
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (context == &KVOContext) {
//            var playerItem = object as! AVPlayerItem
            
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: - Private methods
    
    private func setupInitialUIAndPlayer() -> Void {
        self.playButton.setImage(UIImage(named: "play"), forState: .Normal)
        
        var reachability: Reachability = Reachability.reachabilityForInternetConnection()
        if reachability.isReachable() {
            if reachability.isReachableViaWiFi() {
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Best.rawValue
                self.setupPlayer(.Best)
                println("Reachable via WiFi")
            } else {
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.GPRS.rawValue
                self.setupPlayer(.GPRS)
                println("Reachable via Cellular")
            }
        } else {
            println("*** Not reachable!")
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
        
        var playerItem = AVPlayerItem(URL: url!)
        self.player = AVPlayer(playerItem: playerItem!)
    }
    
}
