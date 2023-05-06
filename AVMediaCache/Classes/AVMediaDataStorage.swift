//
//  AVMediaDataStorage.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

class AVMediaDataStorage: NSObject {
    
    static let shared = AVMediaDataStorage()
        
    private override init() {}
    
    // MARK: -
    
    func completeFileURLWithURL(_ url: URL?) -> URL? {
        
        let unit = AVMediaDataUnitPool.shared.unitWithURL(url)
        let fileURL = unit?.fileURL()
        unit?.workingRelease()
        return fileURL
    }
    
    func readerWithRequest(_ request: AVMediaDataRequest?) -> AVMediaDataReader? {
        
        guard let request = request, !request.url.absoluteString.isEmpty else { return nil }
        let reader = AVMediaDataReader(request)
        return reader
    }
    
    func loaderWithRequest(_ request: AVMediaDataRequest?) -> AVMediaDataLoader? {
        
        guard let request = request, !request.url.absoluteString.isEmpty else { return nil }
        let loader = AVMediaDataLoader(request)
        return loader
    }
    
    func cacheItemWithURL(_ url: URL?) -> AVMediaDataCacheItem? {
        AVMediaDataUnitPool.shared.cacheItemWithURL(url)
    }
    
    func allCacheItem() -> [AVMediaDataCacheItem] {
        AVMediaDataUnitPool.shared.allCacheItem()
    }
    
    func deleteUnitsWithLength(_ length: Int64) {
        AVMediaDataUnitPool.shared.deleteUnitsWithLength(length)
    }
    
    func deleteAllUnits() {
        AVMediaDataUnitPool.shared.deleteAllUnits()
    }
    
    func totalCacheLength() -> Int64 {
        AVMediaDataUnitPool.shared.totalCacheLength()
    }
    
    func totalCacheLengthWithCompleted(_ isCompleted: Bool) -> Int64 {
        AVMediaDataUnitPool.shared.totalCacheLengthWithCompleted(isCompleted)
    }
}
