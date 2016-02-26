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

private let kAnnouncementDisplayOk = "Now On Air:"

enum ChannelType: Int {
    case Stream = 0
    case AMusic = 1
    case Jazz = 2
}

enum MusicQuality: Int {
    case Best = 0
    case Edge = 1
}

enum RadioManagerError: ErrorType { // Consider using String
    // Generic errors
    case NetworkRequestError(String)
    case NetworkDataInconsistencyError(String)
    case DataTransformationError(String)
    // Specific errors
    case FailedToObtainTrackInfo(String)
    case FailedToObtainArtworkURL(String)
    
    func toString() -> String {
        switch self {
        case .NetworkRequestError(let message):
            return message
        case .NetworkDataInconsistencyError(let message):
            return message
        case DataTransformationError(let message):
            return message
        case FailedToObtainTrackInfo(let message):
            return message
        case FailedToObtainArtworkURL(let message):
            return message
        }
    }
}

enum Result<T> {
    case Success(T)
    case Failure(RadioManagerError)
}

class RadioManager {
    
    private static let kXMLBaseUrl = "http://aristocrats.fm"
    private static let kMusicBaseUrl = "http://144.76.79.38:8000"
    private static let kArtworksBaseUrl = "http://ws.audioscrobbler.com/2.0"
    
    private static let kAPIKey = "690e1ed3bc00bc91804cd8f7fe5ed6d4"
    
    private enum Endpoint {
        case XML(ChannelType)
        case Music(ChannelType, MusicQuality)
        case Artwork(String)
        
        func urlString() -> String {
            switch self {
            case .XML(let channel):
                switch channel {
                case .Stream:
                    return "\(kXMLBaseUrl)/service/nowplaying-aristocrats3.xml"
                case .AMusic:
                    return "\(kXMLBaseUrl)/service/nowplaying-amusic3.xml"
                case .Jazz:
                    return "\(kXMLBaseUrl)/service/nowplaying-ajazz3.xml"
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
    
    func fetchTrack(channel: ChannelType, callback: (Result<Track>) -> Void) {
        let urlString = Endpoint.XML(channel).urlString()
        
        p_HTTPGet(urlString) {
            (data: NSData?, error: NSError?) -> Void in
            if error != nil {
                print("*** Error: \(error!.localizedDescription)")
                callback(.Failure(.NetworkRequestError(error!.localizedDescription)))
            } else {
                guard let xmlString = NSString(data:data!, encoding:NSUTF8StringEncoding) else {
                    callback(.Failure(.DataTransformationError("Failed to initialize XML string with data.")))
                    return
                }
                
                let (track, message) = XMLParser.parse(xmlString as String, channel: channel)
                
                guard track != nil else {
                    callback(.Failure(.DataTransformationError("Failed to parse XML and create Track object.")))
                    return
                }
                
                if let message = message {
                    if message.containsString(kAnnouncementDisplayOk) {
                        callback(.Success(track!))
                    } else {
                        callback(.Failure(.FailedToObtainTrackInfo(message)))
                    }
                } else {
                    callback(.Success(track!))
                }
            }
        }
    }
    
    func fetchArtwork(artist: String, callback: (Result<UIImage>) -> Void) {
        p_fetchArtworkUrl(artist) { [weak self]
            (result: Result<String>) -> Void in
            guard let strongSelf = self else { return }
            
            switch result {
            case .Success(let artworkUrlString):
                strongSelf.p_imageFromUrl(artworkUrlString, callback: callback)
            case .Failure(let error):
                callback(.Failure(error))
            }
            
        }
    }

    // MARK: - Private methods
    
    private func p_HTTPSendRequest(request: NSMutableURLRequest, callback: (NSData?, NSError?) -> Void) {
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
    
    private func p_HTTPGet(url: String, callback: (NSData?, NSError?) -> Void) {
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        p_HTTPSendRequest(request, callback: callback)
    }
    
    private func p_fetchArtworkUrl(artist: String, callback: (Result<String>) -> Void) {
        let urlString = Endpoint.Artwork(artist).urlString()
        
        p_HTTPGet(urlString) {
            (data: NSData?, error: NSError?) -> Void in
            
            if (error != nil) {
                callback(.Failure(.NetworkRequestError(error!.localizedDescription)))
            } else {
                var imgUrlString: String?
                
                let json = JSON(data: data!)
                if (json["error"] != nil) {
                    if let errorMessage = json["message"].string {
                        callback(.Failure(.NetworkDataInconsistencyError(errorMessage)))
                        return
                    }
                } else {
                    
                    if let imagesArray = json["artist"]["image"].arrayObject {
                        for imgDict in imagesArray {
                            if let dict = imgDict as? [String : String] {
                                if (dict["size"] == "extralarge") {
                                    imgUrlString = dict["#text"]
                                    break
                                }
                            } else {
                                print("*** Type casting error.")
                            }
                        }
                    }
                    
                    if let imgUrlString = imgUrlString {
                        callback(.Success(imgUrlString))
                    } else {
                        callback(.Failure(.FailedToObtainArtworkURL("Failed to obtain image URL string from JSON.")))
                    }
                }
            
            }
        }
    }
    
    private func p_imageFromUrl(urlString: String, callback: (Result<UIImage>) -> Void) {
        if let url = NSURL(string: urlString) {
            let request = NSURLRequest(URL: url)
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                (response: NSURLResponse?, data: NSData?, error: NSError?) -> Void in
                if (error != nil) {
                    print("*** Error: \(error!.localizedDescription)")
                    // Can't fetch artwork, use the default one
                    let artwork = UIImage(named: "default_artwork")
                    if let artwork = artwork {
                        callback(.Success(artwork))
                    } else {
                        callback(.Failure(.DataTransformationError("Failed to create artwork image from data.")))
                    }
                } else {
                    if let imageData = data as NSData? {
                        let artwork = UIImage(data: imageData)
                        if let artwork = artwork {
                            callback(.Success(artwork))
                        } else {
                            callback(.Failure(.DataTransformationError("Failed to create artwork image from data.")))
                        }
                    } else {
                        callback(.Failure(.NetworkDataInconsistencyError("Failed to fetch artwork data from server.")))
                    }
                }
            }
        }
    }

}
