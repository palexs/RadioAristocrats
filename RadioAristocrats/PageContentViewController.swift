//
//  PageContentViewController.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import UIKit
import MediaPlayer
import AutoScrollLabel
import ReachabilitySwift

struct State {
    var channel: ChannelType
    var quality: MusicQuality
}

protocol PageContentViewControllerDelegate {
    func pageContentViewController(controller: PageContentViewController, didRecievePlayButtonTapWithState state: State)
    func pageContentViewController(controller: PageContentViewController, didRecieveMusicQualitySwitchWithState state: State)
}

class PageContentViewController: UIViewController {
    
    private let kDefaultStreamColor = UIColor(red: 169/255, green: 29/255, blue: 65/255, alpha: 1.0) // #A91D41
    private let kDefaultAMusicColor = UIColor(red: 0/255, green: 48/255, blue: 74/255, alpha: 1.0) // #00304A
    private let kDefaultJazzColor = UIColor(red: 169/255, green: 29/255, blue: 65/255, alpha: 1.0) // #A91D41
    private let kDefaultOnAirColor = UIColor(red: 158/255, green: 158/255, blue: 158/255, alpha: 1.0) // #9E9E9E

    private let kUpdateInterval: NSTimeInterval = 3
    private var channel: ChannelType?
    private var timer = NSTimer()
    
    var pageIndex: Int?
    var delegate: PageContentViewControllerDelegate?

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: CBAutoScrollLabel!
    @IBOutlet weak var artistNameLabel: CBAutoScrollLabel!
    @IBOutlet weak var musicQuialitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var musicQualityLabel: UILabel!
    
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
        
        delegate = PlayerManager.sharedPlayer
        
        p_setupInitialUI()
        p_setDefaultColors()
        p_setUkrainianLanguageIfThursday()
        p_fetchTrack()
        
        ReachabilityManager.sharedManager.onReachabilityStatusChange = {(prevStatus: Reachability.NetworkStatus, currStatus: Reachability.NetworkStatus) -> Void in
            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                
                switch (currStatus) {
                case .NotReachable:
                    PlayerManager.sharedPlayer.pause()
                    strongSelf.p_updatePlayButton()
                    strongSelf.trackTitleLabel.text = LocalizableString.Error.localizedText(LocalizableString.isTodayThursday())
                    strongSelf.artistNameLabel.text = LocalizableString.NoInternetConnection.localizedText(LocalizableString.isTodayThursday())
                case .ReachableViaWWAN, .ReachableViaWiFi:
                    if (prevStatus == .NotReachable) { // Recover from Internet connection loss
                        PlayerManager.sharedPlayer.updatePlayerForState(strongSelf.p_getCurrentUIState())
                    }
                }
            })
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_notificationHandler:", name: kViewControllerRemotePlayPauseCommandNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_notificationHandler:", name: UIApplicationSignificantTimeChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_updatePlayButtonNotificationHandler:", name: kViewControllerUpdatePlayButtonNotification, object: nil)
        
        timer = NSTimer.scheduledTimerWithTimeInterval(kUpdateInterval, target:self, selector: "p_timerFired", userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        timer.invalidate()
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationSignificantTimeChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kViewControllerRemotePlayPauseCommandNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kViewControllerUpdatePlayButtonNotification, object: nil)
        
        delegate = nil
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton?) {
        
        if (ReachabilityManager.sharedManager.isInternetConnectionAvailable() == false) {
            return
        }
        
        if let delegate = self.delegate {
            let state = p_getCurrentUIState()
            delegate.pageContentViewController(self, didRecievePlayButtonTapWithState: state)
        }
        
        p_updatePlayButton()
    }
    
    @IBAction func indexChanged(sender: UISegmentedControl) {
        if let delegate = self.delegate {
            let state = p_getCurrentUIState()
            delegate.pageContentViewController(self, didRecieveMusicQualitySwitchWithState: state)
        }
    }
    
    // MARK: - Notification Handlers
    
    func p_notificationHandler(notification: NSNotification) -> Void {
        if (notification.name == kViewControllerRemotePlayPauseCommandNotification) {
            p_updatePlayButton()
        } else if (notification.name == UIApplicationSignificantTimeChangeNotification) {
            p_setUkrainianLanguageIfThursday()
        } else {
            print("*** Received unknown notification!")
        }
    }
    
    func p_updatePlayButtonNotificationHandler(notification: NSNotification) -> Void {
        p_updatePlayButton()
    }
    
    // MARK: - Private methods
    
    private func p_fetchTrack() -> Void {
        
        if (ReachabilityManager.sharedManager.isInternetConnectionAvailable() == false) {
            trackTitleLabel.text = LocalizableString.Error.localizedText(LocalizableString.isTodayThursday())
            artistNameLabel.text = LocalizableString.NoInternetConnection.localizedText(LocalizableString.isTodayThursday())
            return
        }
        
        RadioManager.sharedInstance.fetchTrack(channel!) {
            (result: Result<Track>) -> Void in
            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                
                switch result {
                case .Success(let track):
                    strongSelf.p_updateUIForTrack(track)
                case .Failure(let error):
                    switch error {
                    case .FailedToObtainTrackInfo:
                        let unknownTitle = LocalizableString.UnknownTrack.localizedText(LocalizableString.isTodayThursday())
                        let unknownArtist = LocalizableString.UnknownArtist.localizedText(LocalizableString.isTodayThursday())
                        let unknownTrack = Track(title: unknownTitle, artist: unknownArtist)
                        strongSelf.p_updateUIForTrack(unknownTrack)
                    default:
                        let errorTitle = LocalizableString.NoTrackInfoErrorMessage.localizedText(LocalizableString.isTodayThursday())
                        let errorArtist = error.toString()
                        let errorTrack = Track(title: errorTitle, artist: errorArtist)
                        strongSelf.p_updateUIForTrack(errorTrack)
                    }
                }
                
            })
        }
    }
    
    private func p_updateUIForTrack(track: Track) -> Void {
        if (track.title == kTrackEmptyString || track.artist == kTrackEmptyString) {
            trackTitleLabel.textColor = kDefaultOnAirColor
            trackTitleLabel.text = LocalizableString.OnAir.localizedText(LocalizableString.isTodayThursday())
            artistNameLabel.text = " "
        } else {
            trackTitleLabel.textColor = UIColor.blackColor()
            trackTitleLabel.text = track.title
            artistNameLabel.text = track.artist
        }
    }
    
    private func p_setupInitialUI() -> Void {
        p_setupInitialTrackLabels()
        p_updatePlayButton()
        p_setDefaultLogo()
        
        // Hide music quality switch for Jazz channel
        let shouldQualityControllBeHidden: Bool = channel! == .Jazz
        musicQuialitySegmentedControl.hidden = shouldQualityControllBeHidden
        musicQualityLabel.hidden = shouldQualityControllBeHidden
        
        // Music quality switch value should coincide with selected player quality
        if (PlayerManager.sharedPlayer.channel == channel!) {
            musicQuialitySegmentedControl.selectedSegmentIndex = PlayerManager.sharedPlayer.quality.rawValue
        }
    }
    
    private func p_setupInitialTrackLabels() -> Void {
        var font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        p_setupAutoScrollLabel(trackTitleLabel, font: font)
        font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        p_setupAutoScrollLabel(artistNameLabel, font: font)
    }
    
    private func p_getCurrentUIState() -> State {
        let quality = MusicQuality(rawValue: musicQuialitySegmentedControl.selectedSegmentIndex)
        return State(channel: channel!, quality: quality!)
    }
    
    private func p_updatePlayButton() -> Void {
        var image: UIImage?
        
        let state = p_getCurrentUIState()
        let isPlayerPaused: Bool
        if (state.channel == PlayerManager.sharedPlayer.channel) {
            isPlayerPaused = PlayerManager.sharedPlayer.isPaused()
        } else {
            isPlayerPaused = true
        }
        
        if (isPlayerPaused) {
            switch channel! {
                case .Stream, .Jazz:
                    image = UIImage(named: "play")
                case .AMusic:
                    image = UIImage(named: "play_a")
            }
        } else {
            switch channel! {
            case .Stream, .Jazz:
                image = UIImage(named: "pause")
            case .AMusic:
                image = UIImage(named: "pause_a")
            }
        }
        
        playButton.setImage(image, forState: .Normal)
    }
    
    private func p_setDefaultColors() -> Void {
        switch channel! {
        case .Stream:
            musicQuialitySegmentedControl.tintColor = kDefaultStreamColor
        case .AMusic:
            musicQuialitySegmentedControl.tintColor = kDefaultAMusicColor
        case .Jazz:
            musicQuialitySegmentedControl.tintColor = kDefaultJazzColor
        }
    }
    
    private func p_setDefaultLogo() -> Void {
        switch (channel!) {
        case .Stream:
            logoImageView.image = UIImage(named: "logo_ru")
        case .AMusic:
            logoImageView.image = UIImage(named: "logo_a_music")
        case .Jazz:
            logoImageView.image = UIImage(named: "logo_a_jazz")
        }
    }
    
    private func p_setUkrainianLanguageIfThursday() -> Void {
        let isThursday = LocalizableString.isTodayThursday()
        p_setDefaultLogo()
        if (isThursday && channel! == .Stream) {
            logoImageView.image = UIImage(named: "logo_ua")
        }
        
        musicQualityLabel.text = LocalizableString.Quality.localizedText(isThursday)
        musicQuialitySegmentedControl.setTitle(LocalizableString.MusicQualityBest.localizedText(isThursday), forSegmentAtIndex: MusicQuality.Best.rawValue)
    }
    
    func p_timerFired() -> Void {
        p_fetchTrack()
        PlayerManager.sharedPlayer.updateSongInfo()
    }
        
    func p_setupAutoScrollLabel(label: CBAutoScrollLabel, font: UIFont) -> Void {
        // Headline - UIFontTextStyleHeadline, Subheadline - UIFontTextStyleSubheadline
        label.text = kTrackEmptyString
        label.font = font
        label.textAlignment = NSTextAlignment.Center
        label.labelSpacing = 30
        label.pauseInterval = 2.0
        label.scrollSpeed = 30.0
        label.textColor = UIColor.blackColor()
        label.scrollDirection = CBAutoScrollDirection.Left
    }
}
