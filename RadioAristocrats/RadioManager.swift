//
//  RadioManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

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
    
    private enum Endpoint {
        case XML(ChannelType)
        case Music(ChannelType, MusicQuality)
        
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

            }
        }
    }
    
    class var sharedInstance: RadioManager {
        struct Static {
            static let instance: RadioManager = RadioManager()
        }
        return Static.instance
    }
    
    class func endpointUrlString(channel: ChannelType, quality: MusicQuality) -> String {
        return Endpoint.Music(channel, quality).urlString()
    }
    
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
    
}
