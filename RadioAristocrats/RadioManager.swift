//
//  RadioManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

class RadioManager {
    
    enum ChannelType: Int {
        case Stream = 0
        case AMusic = 1
        case Jazz = 2
    }
    
    enum MusicQuality: Int {
        case Best = 0
        case Edge = 1
    }
    
    enum Endpoint {
        case XML(ChannelType)
        case Music(ChannelType, MusicQuality)
        
        func urlString() -> String {
            switch self {
            case .XML(let channel):
                switch channel {
                    case .Stream:
                        return "http://aristocrats.fm/service/NowOnAir.xml"
                    case .AMusic:
                        return "http://aristocrats.fm/service/nowplaying-amusic.xml"
                    case .Jazz:
                        return "http://aristocrats.fm/service/nowplaying-ajazz.xml"
                }

            case .Music(let channel, let quality):
                switch quality {
                    case .Best:
                        switch channel {
                            case .Stream:
                                return "http://144.76.79.38:8000/live2"
                            case .AMusic:
                                return "http://144.76.79.38:8000/amusic-128"
                            case .Jazz:
                                return "http://144.76.79.38:8000/ajazz"
                        }
                    case .Edge:
                        switch channel {
                            case .Stream:
                                return "http://144.76.79.38:8000/live2-64"
                            case .AMusic:
                                return "http://144.76.79.38:8000/amusic-64"
                            case .Jazz:
                                return "http://144.76.79.38:8000/ajazz"
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
    
    private func HTTPsendRequest(request: NSMutableURLRequest, callback: (NSData?, NSError?) -> Void) {
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
        HTTPsendRequest(request, callback: callback)
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
