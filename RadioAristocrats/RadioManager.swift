//
//  RadioManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

class RadioManager {
    
    internal enum ChannelType: Int {
        case Stream = 0
        case AMusic = 1
        case Jazz = 2
    }
    
    private struct Endpoint {
        static let StreamUrl = "http://aristocrats.fm/service/NowOnAir.xml"
        static let AMusicUrl = "http://aristocrats.fm/service/nowplaying-amusic.xml"
        static let JazzUrl = "http://aristocrats.fm/service/nowplaying-ajazz.xml"
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
    
    func fetchTrack(channel: ChannelType, callback: (Track?, NSError?) -> Void) {
        var url: String?
        
        switch channel {
            case .Stream:
                url = Endpoint.StreamUrl
            case .AMusic:
                url = Endpoint.AMusicUrl
            case .Jazz:
                url = Endpoint.JazzUrl
        }
        
        HTTPGet(url!) {
            (data: NSData?, error: NSError?) -> Void in
            if error != nil {
                print("*** Error: \(error!.localizedDescription)")
                callback(nil, error)
            } else {
                let xmlString = NSString(data:data!, encoding:NSUTF8StringEncoding) as! String
                let track = XMLParser.parse(xmlString, channel: channel)
                callback(track, nil)
            }
        }
        
    }
    
}
