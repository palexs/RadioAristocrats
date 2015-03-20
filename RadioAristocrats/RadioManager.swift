//
//  RadioManager.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

class RadioManager {
    
    private struct Endpoint {
        static let TrackUrl = "http://m.aristocrats.fm/cs.html"
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
        var request = NSMutableURLRequest(URL: NSURL(string: url)!)
        HTTPsendRequest(request, callback: callback)
    }
    
    func fetchCurrentTrack(callback: (Track?, NSError?) -> Void) {
        HTTPGet(Endpoint.TrackUrl) {
            (data: NSData?, error: NSError?) -> Void in
            if error != nil {
                println("*** Error: \(error!.localizedDescription)")
                callback(nil, error)
            } else {
                let htmlString = NSString(data:data!, encoding:NSUTF8StringEncoding) as String
                let track = HtmlParser.parse(htmlString)
                callback(track, nil)
            }
        }
    }
    
}
