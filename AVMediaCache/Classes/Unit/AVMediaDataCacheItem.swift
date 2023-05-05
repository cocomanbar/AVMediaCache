//
//  AVMediaDataCacheItem.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/25.
//

import Foundation

public struct AVMediaDataCacheItem {
    
    public private(set) var url: URL
    public private(set) var totalLength: Int64
    public private(set) var cacheLength: Int64
    public private(set) var vaildLength: Int64
    public private(set) var zones: [AVMediaDataCacheItemZone]
    
    init(url: URL, totalLength: Int64, cacheLength: Int64, vaildLength: Int64, zones: [AVMediaDataCacheItemZone]) {
        self.url = url
        self.totalLength = totalLength
        self.cacheLength = cacheLength
        self.vaildLength = vaildLength
        self.zones = zones
    }
}
