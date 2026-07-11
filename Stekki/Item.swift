//
//  Item.swift
//  Stekki
//
//  Created by 濵口椋大 on 2026/07/11.
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
