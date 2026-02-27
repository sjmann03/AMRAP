//
//  Item.swift
//  AMRAP
//
//  Created by Spencer Mann on 2/26/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
