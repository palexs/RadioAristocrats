//
//  HtmlParser.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/6/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

class HtmlParser {
   
    private struct HtmlTag {
        static let TitleOpen = "<h4>"
        static let TitleClose = "</h4>"
        static let ArtistOpen = "<h5>"
        static let ArtistClose = "</h5>"
    }
    
    class func parse(html: String) -> Track? {
        let track = Track(title: "AAAAAA", artist: "BBBBB")
        return track
    }
    
}
