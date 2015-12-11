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

struct State {
    var channel: ChannelType
    var quality: MusicQuality
}

protocol PageContentViewControllerDelegate {
    func pageContentViewController(controller: PageContentViewController, didRecievePlayButtonTapWithState state: State)
    func pageContentViewController(controller: PageContentViewController, didRecieveMusicQualitySwitchWithState state: State)
}

class PageContentViewController: UIViewController {
    
    private let kDefaultStreamColor = UIColor(red: 212/255, green: 68/255, blue: 79/255, alpha: 1.0) // #D4444F
    private let kDefaultAMusicColor = UIColor(red: 0/255, green: 48/255, blue: 74/255, alpha: 1.0) // #00304A
    private let kDefaultJazzColor = UIColor(red: 212/255, green: 68/255, blue: 79/255, alpha: 1.0) // #D4444F

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
        
        func localizedText(let isThursday: Bool) -> String {
            if (isThursday) { // Ukrainian
                switch self {
                    case .UnknownTrack:
                        return "Невідомий трек"
                    case .UnknownArtist:
                        return "Невідомий виконавець"
                    case .NoTrackInfoErrorMessage:
                        return "Упс, щось пішло шкереберть!"
                    case .MusicQualityBest:
                        return "Найкраща"
                    case .Quality:
                        return "Якість"
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
                }
            }
        }
    }

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!
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
        
        p_setupInitialUI()
        p_setDefaultColors()
        p_setUkrainianLanguageIfThursday()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_notificationHandler:", name: ViewControllerRemotePlayPauseCommandReceivedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_notificationHandler:", name: UIApplicationSignificantTimeChangeNotification , object: nil)
        
        p_fetchTrack()
        
        timer = NSTimer.scheduledTimerWithTimeInterval(kUpdateInterval, target:self, selector: "p_timerFired", userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        
        timer.invalidate()
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationSignificantTimeChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ViewControllerRemotePlayPauseCommandReceivedNotification, object: nil)
        
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
        if (notification.name == ViewControllerRemotePlayPauseCommandReceivedNotification) {
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
                
                // Set default now playing info
                let defaultAlbumArtWork = MPMediaItemArtwork(image: UIImage(named: "default_artwork")!)
                var songInfo: [String: AnyObject] = [
                    MPMediaItemPropertyTitle: Strings.UnknownTrack.localizedText(strongSelf.p_isTodayThursday()),
                    MPMediaItemPropertyArtist: Strings.UnknownArtist.localizedText(strongSelf.p_isTodayThursday()),
                    MPMediaItemPropertyArtwork: defaultAlbumArtWork,
                    MPMediaItemPropertyPlaybackDuration: NSNumber(integer: 0)
                ]
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
                
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
                                        let alert = UIAlertController(title: "Ошибка", message: error.toString(), preferredStyle: UIAlertControllerStyle.Alert)
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
                        let alert = UIAlertController(title: "Ошибка", message: error.toString(), preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                        strongSelf.presentViewController(alert, animated: true, completion: nil)
                    }
                    
                }
                })
        }
    }
    
    private func p_setupInitialUI() -> Void {

        p_updatePlayButton()
        
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
        if (p_isTodayThursday()) {
            logoImageView.image = UIImage(named: "logo_ua")
        } else {
            logoImageView.image = UIImage(named: "logo_ru")
        }
        
        musicQualityLabel.text = Strings.Quality.localizedText(isThursday)
        musicQuialitySegmentedControl.setTitle(Strings.MusicQualityBest.localizedText(isThursday), forSegmentAtIndex: MusicQuality.Best.rawValue)
    }
    
    func p_timerFired() -> Void {
        p_fetchTrack()
    }
}
