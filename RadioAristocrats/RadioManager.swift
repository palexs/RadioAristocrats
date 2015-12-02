//
//  RadioManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

enum ChannelType: Int {
    case Stream = 0
    case AMusic = 1
    case Jazz = 2
}

enum MusicQuality: Int {
    case Best = 0
    case Edge = 1
}

class RadioManager {
    
    private static let kXMLBaseUrl = "http://aristocrats.fm"
    private static let kMusicBaseUrl = "http://144.76.79.38:8000"
    private static let kArtworksBaseUrl = "http://ws.audioscrobbler.com/2.0"
    
    private static let kAPIKey = "690e1ed3bc00bc91804cd8f7fe5ed6d4"
    private let kErrorDomain = "aristocrats.fm.Error.RadioManager"
    
    private enum Endpoint {
        case XML(ChannelType)
        case Music(ChannelType, MusicQuality)
        case Artwork(String)
        
        func urlString() -> String {
            switch self {
            case .XML(let channel):
                switch channel {
                    case .Stream:
                        return "\(kXMLBaseUrl)/service/NowOnAir.xml"
                    case .AMusic:
                        return "\(kXMLBaseUrl)/service/nowplaying-amusic.xml"
                    case .Jazz:
                        return "\(kXMLBaseUrl)/service/nowplaying-ajazz.xml"
                }

            case .Music(let channel, let quality):
                switch quality {
                    case .Best:
                        switch channel {
                            case .Stream:
                                return "\(kMusicBaseUrl)/live2"
                            case .AMusic:
                                return "\(kMusicBaseUrl)/amusic-128"
                            case .Jazz:
                                return "\(kMusicBaseUrl)/ajazz"
                        }
                    case .Edge:
                        switch channel {
                            case .Stream:
                                return "\(kMusicBaseUrl)/live2-64"
                            case .AMusic:
                                return "\(kMusicBaseUrl)/amusic-64"
                            case .Jazz:
                                return "\(kMusicBaseUrl)/ajazz"
                        }
                    
                }
                
            case .Artwork(let artist):
                let escapedArtist = artist.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
                return "\(kArtworksBaseUrl)/?method=artist.getInfo&artist=\(escapedArtist!)&api_key=\(kAPIKey)&autocorrect=1&format=json"
            }
        }
    }
    
    // MARK: - Public API
    
    class var sharedInstance: RadioManager {
        struct Static {
            static let instance: RadioManager = RadioManager()
        }
        return Static.instance
    }
    
    class func endpointUrlString(channel: ChannelType, quality: MusicQuality) -> String {
        return Endpoint.Music(channel, quality).urlString()
    }
    
    func fetchTrack(channel: ChannelType, callback: ((track: Track?, message: String?), NSError?) -> Void) {
        let urlString = Endpoint.XML(channel).urlString()
        
        HTTPGet(urlString) {
            (data: NSData?, error: NSError?) -> Void in
            if error != nil {
                print("*** Error: \(error!.localizedDescription)")
                callback((nil, nil), error)
            } else {
                let xmlString = NSString(data:data!, encoding:NSUTF8StringEncoding) as! String
                let (track, message) = XMLParser.parse(xmlString, channel: channel)
                callback((track, message), nil)
            }
        }
    }
    
    func fetchArtwork(artist: String, callback: (UIImage?, NSError?) -> Void) {
        fetchArtworkUrl(artist) { [weak self]
            (artworkUrlString: String?, error: NSError?) -> Void in
            guard let strongSelf = self else { return }
            
            if (error != nil || artworkUrlString == nil) {
                callback(nil, error)
            } else {
                strongSelf.imageFromUrl(artworkUrlString!, callback: callback)
            }
            
        }
    }

    // MARK: - Private methods
    
    private func HTTPSendRequest(request: NSMutableURLRequest, callback: (NSData?, NSError?) -> Void) {
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {
            data, response, error in
                if error != nil {
                    callback(nil, error)
                } else {
                    callback(data, nil)
                }
        })
        
        task.resume()
    }
    
    private func HTTPGet(url: String, callback: (NSData?, NSError?) -> Void) {
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        HTTPSendRequest(request, callback: callback)
    }
    
    private func fetchArtworkUrl(artist: String, callback: (String?, NSError?) -> Void) {
        let urlString = Endpoint.Artwork(artist).urlString()
        
        HTTPGet(urlString) { [weak self]
            (data: NSData?, error: NSError?) -> Void in
            guard let strongSelf = self else { return }
            
            if (error != nil) {
                print("*** Error: \(error!.localizedDescription)")
                callback(nil, error!)
            } else {
                var imgUrlString: String?
                
                let json = JSON(data: data!)
                let error = json["error"]
                if (error != nil) {
                    let jsonError: NSError?
                    if let errorMessage = json["message"].string {
                        jsonError = NSError(domain: strongSelf.kErrorDomain, code: -123, userInfo: [NSLocalizedDescriptionKey : errorMessage])
                    } else {
                        jsonError = NSError(domain: strongSelf.kErrorDomain, code: -123, userInfo: nil)
                    }
                    callback(nil, jsonError)
                } else {
                    
                    if let imagesArray = json["artist"]["image"].arrayObject {
                        for imgDict in imagesArray {
                            let dict = imgDict as! [String : String]
                            if (dict["size"] == "extralarge") {
                                imgUrlString = dict["#text"]
                                break
                            }
                        }
                    }
                    
                    callback(imgUrlString, nil)
                }
            
            }
        }
    }
    
    private func imageFromUrl(urlString: String, callback: (UIImage?, NSError?) -> Void) {
        if let url = NSURL(string: urlString) {
            let request = NSURLRequest(URL: url)
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                (response: NSURLResponse?, data: NSData?, error: NSError?) -> Void in
                if (error != nil) {
                    callback(nil, error)
                } else {
                    if let imageData = data as NSData? {
                        let artwork = UIImage(data: imageData)
                        callback(artwork, nil)
                    } else {
                        let err = NSError(domain: self.kErrorDomain, code: -122, userInfo: nil)
                        callback(nil, err)
                    }
                }
            }
        }
    }

}
