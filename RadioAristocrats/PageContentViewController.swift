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
    
    private var KVOContext: UInt8 = 1
    private var player: AVPlayer?

    var pageIndex: Int?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        // Initialize player
        let url = NSURL(string: Endpoint.MusicBestQualityUrl)
        var playerItem = AVPlayerItem(URL: url!)
        self.player = AVPlayer(playerItem: playerItem!)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
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
    
    // MARK: -
    
    @IBAction func playButtonTouched(sender: UIButton) {
        println("Play button touched.")
        
        if (self.player?.rate == 0.0) {
            self.player?.play()
        } else {
            self.player?.pause()
        }
    }
    
    // MARK: - KVO
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (context == &KVOContext) {
            var playerItem = object as! AVPlayerItem
            
            if (self.player?.rate == 0.0) {
                self.playButton.setImage(UIImage(named: "pause"), forState: .Normal)
            } else {
                self.playButton.setImage(UIImage(named: "play"), forState: .Normal)
            }
            
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
}
