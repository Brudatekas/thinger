//
//  Item.swift
//  thinger
//
//  Created by Tarik Khafaga on 30.12.2025.
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
