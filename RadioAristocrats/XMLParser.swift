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
    
    class func parse(xmlString: String, channel: RadioManager.ChannelType) -> (Track?, String?) {
        let xml = SWXMLHash.parse(xmlString)
        var title: String?
        var artist: String?
        
        switch channel {
            case .Stream:
                title = xml["Schedule"]["Event"]["Song"].element?.attributes["title"]
                artist = xml["Schedule"]["Event"]["Song"]["Artist"].element?.attributes["name"]
            
            case .AMusic, .Jazz:
                title = xml["Playlist"]["song"].element?.attributes["title"]
                artist = xml["Playlist"]["artist"].element?.attributes["title"]
        }
        
        let message = xml["Schedule"]["Event"]["Announcement"].element?.attributes["Display"]
        let track = Track(title:title!, artist:artist!)
        return (track, message)
    }
    
}
