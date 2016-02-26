//
//  PageContentViewController.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import UIKit
import ReachabilitySwift
import MediaPlayer
import AutoScrollLabel

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

    private let kThursday = 5
    private let kUpdateInterval: NSTimeInterval = 5
    private var _channel: ChannelType?
    private var timer = NSTimer()
    
    var pageIndex: Int?
    var delegate: PageContentViewControllerDelegate?
    
    private enum Strings: String {
        case UnknownTrack
        case UnknownArtist
        case NoTrackInfoErrorMessage
        case MusicQualityBest
        case Quality
        case Error
        
        func localizedText(let isThursday: Bool) -> String {
            if (isThursday) { // Ukrainian
                switch self {
                case .UnknownTrack:
                    return "Невідомий трек"
                case .UnknownArtist:
                    return "Невідомий виконавець"
                case .NoTrackInfoErrorMessage:
                    return "Йой, щось пішло шкереберть!"
                case .MusicQualityBest:
                    return "Найкраща"
                case .Quality:
                    return "Якість"
                case .Error:
                    return "Помилка"
                }
            } else { // Russian
                switch self {
                case .UnknownTrack:
                    return "Неизвестный трек"
                case .UnknownArtist:
                    return "Неизвестный исполнитель"
                case .NoTrackInfoErrorMessage:
                    return "Упс, что-то пошло не так!"
                case .MusicQualityBest:
                    return "Лучшее"
                case .Quality:
                    return "Качество"
                case .Error:
                    return "Ошибка"
                }
            }
        }
    }

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: CBAutoScrollLabel!
    @IBOutlet weak var artistNameLabel: CBAutoScrollLabel!
    @IBOutlet weak var musicQuialitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var musicQualityLabel: UILabel!
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        if let aChannel = ChannelType(rawValue: pageIndex!) {
            _channel = aChannel
        } else {
            assertionFailure("*** Failed to set channel type!")
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        delegate = PlayerManager.sharedPlayer
        
        var font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        p_setupAutoScrollLabel(trackTitleLabel, font: font)
        font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        p_setupAutoScrollLabel(artistNameLabel, font: font)
        
        p_setupInitialUI()
        p_setDefaultColors()
        p_setDefaultPlayingInfo()
        p_setUkrainianLanguageIfThursday()
        p_fetchTrack()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_notificationHandler:", name: kViewControllerRemotePlayPauseCommandNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_notificationHandler:", name: UIApplicationSignificantTimeChangeNotification, object: nil)
        
        timer = NSTimer.scheduledTimerWithTimeInterval(kUpdateInterval, target:self, selector: "p_timerFired", userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        timer.invalidate()
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationSignificantTimeChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kViewControllerRemotePlayPauseCommandNotification, object: nil)
        
        delegate = nil
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton?) {
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
    
    // MARK: - Notification Handler
    
    func p_notificationHandler(notification: NSNotification) -> Void {
        if (notification.name == kViewControllerRemotePlayPauseCommandNotification) {
            p_updatePlayButton()
        } else if (notification.name == UIApplicationSignificantTimeChangeNotification) {
            p_setUkrainianLanguageIfThursday()
        } else {
            print("*** Received unknown notification!")
        }
    }
    
    // MARK: - Private methods
    
    private func p_fetchTrack() -> Void {
        RadioManager.sharedInstance.fetchTrack(_channel!) {
            (result: Result<Track>) -> Void in
            dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
                guard let strongSelf = self else { return }
                
                var songInfo: [String: AnyObject] = Dictionary()
                
                switch result {
                case .Success(let track):
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
                            RadioManager.sharedInstance.fetchArtwork(artist) {
                                (result: Result<UIImage>) -> Void in
                                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                    
                                    switch result {
                                    case .Success(let image):
                                        songInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
                                        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
                                    case .Failure(let error):
                                        strongSelf.p_setDefaultPlayingInfo()
                                        let alertTitle = Strings.Error.localizedText(strongSelf.p_isTodayThursday())
                                        let alert = UIAlertController(title: alertTitle, message: error.toString(), preferredStyle: UIAlertControllerStyle.Alert)
                                        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                                        strongSelf.presentViewController(alert, animated: true, completion: nil)
                                    }
                                    
                                })
                            }
                        }
                    }
                    
                case .Failure(let error):
                    switch error {
                    case .FailedToObtainTrackInfo:
                        strongSelf.trackTitleLabel.text = Strings.NoTrackInfoErrorMessage.localizedText(strongSelf.p_isTodayThursday())
                        strongSelf.artistNameLabel.text = error.toString()
                    default:
                        let alertTitle = Strings.Error.localizedText(strongSelf.p_isTodayThursday())
                        let alert = UIAlertController(title: alertTitle, message: error.toString(), preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                        strongSelf.presentViewController(alert, animated: true, completion: nil)
                    }
                    
                }
            })
        }
    }
    
    private func p_setupInitialUI() -> Void {

        p_updatePlayButton()
        p_setDefaultLogo()
        
        let shouldQualityControllBeHidden: Bool = _channel! == .Jazz
        musicQuialitySegmentedControl.hidden = shouldQualityControllBeHidden
        musicQualityLabel.hidden = shouldQualityControllBeHidden
        
//        if (_channel! == .Jazz) {
            // Jazz channel has only Best quality
//            musicQuialitySegmentedControl.removeSegmentAtIndex(MusicQuality.Edge.rawValue, animated: false)
//        }
        
        p_setMusicQualityWithRespectToReachability()
    }
    
    private func p_setMusicQualityWithRespectToReachability() -> Void {
        let reachability: Reachability?
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch _ {
            print("*** Failed to obtain reachability value!")
            reachability = nil
        }
        
        if reachability!.isReachable() {
            if reachability!.isReachableViaWiFi() {
                if (PlayerManager.sharedPlayer.quality != .Best) {
                    musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Best.rawValue
                    if let delegate = self.delegate {
                        let state = State(channel: _channel!, quality: .Best) // p_getCurrentUIState()
                        delegate.pageContentViewController(self, didRecieveMusicQualitySwitchWithState: state)
                    }
                    print("Reachable via WiFi")
                }
            } else {
                if (PlayerManager.sharedPlayer.quality != .Edge) {
                    musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Edge.rawValue
                    if let delegate = self.delegate {
                        let state = State(channel: _channel!, quality: .Edge) // p_getCurrentUIState()
                        delegate.pageContentViewController(self, didRecieveMusicQualitySwitchWithState: state)
                    }
                    print("Reachable via Cellular")
                }
            }
        } else {
            print("*** Not reachable!")
        }
    }
    
    private func p_getCurrentUIState() -> State {
        let quality = MusicQuality(rawValue: musicQuialitySegmentedControl.selectedSegmentIndex)
        return State(channel: _channel!, quality: quality!)
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
            switch _channel! {
                case .Stream, .Jazz:
                    image = UIImage(named: "play")
                case .AMusic:
                    image = UIImage(named: "play_a")
            }
        } else {
            switch _channel! {
            case .Stream, .Jazz:
                image = UIImage(named: "pause")
            case .AMusic:
                image = UIImage(named: "pause_a")
            }
        }
        
        playButton.setImage(image, forState: .Normal)
    }
    
    private func p_setDefaultColors() -> Void {
        switch _channel! {
        case .Stream:
            musicQuialitySegmentedControl.tintColor = kDefaultStreamColor
        case .AMusic:
            musicQuialitySegmentedControl.tintColor = kDefaultAMusicColor
        case .Jazz:
            musicQuialitySegmentedControl.tintColor = kDefaultJazzColor
        }
    }
    
    private func p_setDefaultLogo() -> Void {
        switch (_channel!) {
        case .Stream:
            logoImageView.image = UIImage(named: "logo_ru")
        case .AMusic:
            logoImageView.image = UIImage(named: "logo_a_music")
        case .Jazz:
            logoImageView.image = UIImage(named: "logo_a_jazz")
        }
    }
    
    private func p_isTodayThursday() -> Bool {
        let formatter  = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let myCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let myComponents = myCalendar.components(.Weekday, fromDate: NSDate()) // NSDate() returns today
        let weekDay = myComponents.weekday
        return weekDay == kThursday
    }
    
    private func p_setUkrainianLanguageIfThursday() -> Void {
        let isThursday = p_isTodayThursday()
        p_setDefaultLogo()
        if (isThursday && _channel! == .Stream) {
            logoImageView.image = UIImage(named: "logo_ua")
        }
        
        musicQualityLabel.text = Strings.Quality.localizedText(isThursday)
        musicQuialitySegmentedControl.setTitle(Strings.MusicQualityBest.localizedText(isThursday), forSegmentAtIndex: MusicQuality.Best.rawValue)
    }
    
    func p_timerFired() -> Void {
        p_fetchTrack()
    }
    
    func p_setDefaultPlayingInfo() -> Void {
        let defaultAlbumArtWork = MPMediaItemArtwork(image: UIImage(named: "default_artwork")!)
        let songInfo: [String: AnyObject] = [
            MPMediaItemPropertyTitle: Strings.UnknownTrack.localizedText(p_isTodayThursday()),
            MPMediaItemPropertyArtist: Strings.UnknownArtist.localizedText(p_isTodayThursday()),
            MPMediaItemPropertyArtwork: defaultAlbumArtWork,
            MPMediaItemPropertyPlaybackDuration: NSNumber(integer: 0)
        ]
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
    }
    
    func p_setupAutoScrollLabel(label: CBAutoScrollLabel, font: UIFont) -> Void {
        // Headline - UIFontTextStyleHeadline, Subheadline - UIFontTextStyleSubheadline
        label.text = "--"
        label.font = font
        label.textAlignment = NSTextAlignment.Center
        label.labelSpacing = 30
        label.pauseInterval = 2.0
        label.scrollSpeed = 30.0
        label.textColor = UIColor.blackColor()
        label.scrollDirection = CBAutoScrollDirection.Left
    }
}
