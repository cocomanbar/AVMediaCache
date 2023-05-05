//
//  AVMediaDataCacheItemZone.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/25.
//

import Foundation

public struct AVMediaDataCacheItemZone {
    
    public private(set) var offset: Int64
    public private(set) var length: Int64
    
    init(offset: Int64, length: Int64) {
        self.offset = offset
        self.length = length
    }
}
