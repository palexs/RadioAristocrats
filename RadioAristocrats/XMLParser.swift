//
//  HtmlParser.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/6/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation
import SWXMLHash

class XMLParser {
    
    class func parse(xmlString: String, channel: ChannelType) -> (Track?, String?) {
        let xml = SWXMLHash.parse(xmlString)
        var title: String?
        var artist: String?
        
        switch channel {
            case .Stream, .AMusic, .Jazz:
                title = xml["Playlist"]["song"].element?.attributes["title"]
                artist = xml["Playlist"]["artist"].element?.attributes["title"]
        }
        
        let message = xml["Schedule"]["Event"]["Announcement"].element?.attributes["Display"]
        let track = Track(title:title!, artist:artist!)
        return (track, message)
    }
    
}
