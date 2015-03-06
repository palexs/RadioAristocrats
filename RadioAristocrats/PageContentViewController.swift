//
//  PageContentViewController.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import UIKit

class PageContentViewController: UIViewController {

    var pageIndex: Int?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
    
    @IBAction func playButtonTouched(sender: UIButton) {
        println("Play button touched.")
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        RadioManager.sharedInstance.fetchCurrentTrack {
            (track: Track?, error: NSError?) -> Void in
            println("Track: \(track)")
            self.trackTitleLabel.text = track?.title
            self.artistNameLabel.text = track?.artist
        }
    }
}
