//
//  Track.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/5/15.
//  Copyright (c) 2015 RadioAristocrats. All rights reserved.
//

import Foundation

class Track {
   var title: String?
   var artist: String?
    
    init(title aTitle: String?, artist anArtist: String?) {        
        title = aTitle ?? "--"
        artist = anArtist ?? "--"
    }
}
