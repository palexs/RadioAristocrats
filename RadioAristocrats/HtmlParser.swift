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
        // Get Title
        let rangeTitleOpen = html.rangeOfString(HtmlTag.TitleOpen, options: NSStringCompareOptions.LiteralSearch, range: nil, locale: nil)
        let rangeTitleClose = html.rangeOfString(HtmlTag.TitleClose, options: NSStringCompareOptions.LiteralSearch, range: nil, locale: nil)

        let titleRange: Range<String.Index> = Range<String.Index>(start: rangeTitleOpen!.endIndex, end:rangeTitleClose!.startIndex)
        let title = html.substringWithRange(titleRange)
        
        // Get Artist
        let rangeArtistOpen = html.rangeOfString(HtmlTag.ArtistOpen, options: NSStringCompareOptions.LiteralSearch, range: nil, locale: nil)
        let rangeArtistClose = html.rangeOfString(HtmlTag.ArtistClose, options: NSStringCompareOptions.LiteralSearch, range: nil, locale: nil)
        
        let artistRange: Range<String.Index> = Range<String.Index>(start: rangeArtistOpen!.endIndex, end:rangeArtistClose!.startIndex)
        let artist = html.substringWithRange(artistRange)
        
        let track = Track(title:title, artist:artist)
        return track
    }
    
}
