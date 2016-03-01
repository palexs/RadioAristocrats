//
//  Track.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

let kTrackEmptyString = "--"

class Track: Equatable {
   var title: String
   var artist: String
    
    init(title aTitle: String?, artist anArtist: String?) {
        title = aTitle ?? kTrackEmptyString
        artist = anArtist ?? kTrackEmptyString
        
        if (title.isEmpty) {
            title = kTrackEmptyString
        }
        
        if (artist.isEmpty) {
            artist = kTrackEmptyString
        }
    }

}

func ==(lhs: Track, rhs: Track) -> Bool {
    return lhs.title == rhs.title && lhs.artist == rhs.artist
}
