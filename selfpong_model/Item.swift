//
//  Item.swift
//  selfpong_model
//
//  Created by Aarief Fawwaz Satriahutama on 10/09/26.
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
