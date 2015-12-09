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
    
    private let kDefaultStreamColor = UIColor(red: 212/255, green: 68/255, blue: 79/255, alpha: 1.0) // #D4444F
    private let kDefaultAMusicColor = UIColor(red: 0/255, green: 48/255, blue: 74/255, alpha: 1.0) // #00304A
    private let kDefaultJazzColor = UIColor(red: 212/255, green: 68/255, blue: 79/255, alpha: 1.0) // #D4444F

    private let kThursday = 5
    
    private var KVOContext: UInt8 = 1
    private var player: AVPlayer?
    private var channel: ChannelType?
    
    var pageIndex: Int?
    
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
            channel = aChannel
        } else {
            assertionFailure("*** Failed to set channel type!")
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        p_setupInitialUIAndPlayer()
        p_setDefaultColors()
        p_setUkrainianLanguageIfThursday()
        
        player?.currentItem!.addObserver(self, forKeyPath: "status", options: [], context: &KVOContext)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playButtonTouched:", name: ViewControllerRemotePlayCommandReceivedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playButtonTouched:", name: ViewControllerRemotePauseCommandReceivedNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "p_setUkrainianLanguageIfThursday", name: UIApplicationSignificantTimeChangeNotification , object: nil)
        
        RadioManager.sharedInstance.fetchTrack(channel!) {
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
    
    override func viewWillDisappear(animated: Bool) {
        player?.pause()
        player?.currentItem!.removeObserver(self, forKeyPath: "status", context: &KVOContext)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationSignificantTimeChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ViewControllerRemotePlayCommandReceivedNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ViewControllerRemotePauseCommandReceivedNotification, object: nil)
        player = nil
        
        super.viewWillDisappear(animated)
    }
    
    // MARK: - IBActions
    
    @IBAction func playButtonTouched(sender: UIButton?) {
        print("Play button touched.")
        
        p_updatePlayButton()
        
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
            p_setupPlayer(channel!, quality: index)
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
    
    private func p_setupInitialUIAndPlayer() -> Void {

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
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Best.rawValue
                p_setupPlayer(channel!, quality: MusicQuality.Best)
                print("Reachable via WiFi")
            } else {
                musicQuialitySegmentedControl.selectedSegmentIndex = MusicQuality.Edge.rawValue
                p_setupPlayer(channel!, quality: MusicQuality.Edge)
                print("Reachable via Cellular")
            }
        } else {
            print("*** Not reachable!")
        }
    }
    
    private func p_setupPlayer(channel: ChannelType, quality: MusicQuality) -> Void {
        let url = NSURL(string: RadioManager.endpointUrlString(channel, quality: quality))
        let playerItem = AVPlayerItem(URL: url!)
        player = AVPlayer(playerItem: playerItem)
    }
    
    private func p_updatePlayButton() {
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
    
    private func p_setDefaultColors() {
        switch channel! {
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
    
}
