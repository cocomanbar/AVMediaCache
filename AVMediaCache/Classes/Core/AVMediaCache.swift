//
//  AVMediaCache.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/20.
//

import UIKit
import AVFoundation

public class AVMediaCache: NSObject {
    
    public static let customSchemePrefix = "avmediacache-"
    
    public lazy var mediaCacheLimit: Int64 = 1 * 1024 * 1024 * 1024
    
    private(set) var reportClosure: ReportErrorClosure?
    
    private lazy var currentReousrces: [URL: [AVMediaResourceProxy]] = {
        [URL: [AVMediaResourceProxy]]()
    }()
    
    private lazy var coreLock: NSLock = {
        let lock = NSLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    // MARK: - Init
    
    public static let shared = AVMediaCache.init()
    public override class func copy() -> Any { self }
    public override class func mutableCopy() -> Any { self }
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationMemoryWarningNotification(_:)),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    // MARK: - Report
    
    public func reportError(_ closure: ReportErrorClosure?) {
        reportClosure = closure
    }
    
    // MARK: - URL Convert
    
    public func urlConvertClosure(_ closure: @escaping URLConvertKeyClosure) {
        AVMediaURLUtil.shared.urlConvert = closure
    }
    
    // MARK: - Cache
    
    public func totalCache() -> Int64 {
        AVMediaDataStorage.shared.totalCacheLength()
    }
    
    public func totalCacheLengthWithCompleted(_ isCompleted: Bool) -> Int64 {
        AVMediaDataStorage.shared.totalCacheLengthWithCompleted(isCompleted)
    }
    
    public func cacheItemWithURL(_ url: URL?) -> AVMediaDataCacheItem? {
        AVMediaDataStorage.shared.cacheItemWithURL(url)
    }
    
    public func allCacheItem() -> [AVMediaDataCacheItem] {
        AVMediaDataStorage.shared.allCacheItem()
    }
    
    public func limitCacheIfItNeeded() {
        let totalCacheLength = totalCache()
        if totalCacheLength > mediaCacheLimit {
            AVMediaDataStorage.shared.deleteUnitsWithLength(totalCacheLength - mediaCacheLimit)
        }
    }
    
    public func deleteCacheAll() {
        AVMediaDataStorage.shared.deleteAllUnits()
    }
    
    // MARK: - Download
    
    public func timeoutInterval(_ interval: TimeInterval) {
        AVMediaDownload.download.timeoutInterval = interval
    }
    
    public func additionalHeaders(_ headers: [String: String]) {
        AVMediaDownload.download.additionalHeaders = headers
    }
    
    public func whitelistHeaderKeys(_ whiteHeaderKeys: [String]) {
        AVMediaDownload.download.whitelistHeaderKeys = whiteHeaderKeys  
    }
    
    public func unacceptableContentTypeDisposer(_ disposer: @escaping UnacceptableContentTypeDisposer) {
        AVMediaDownload.download.unacceptableContentTypeDisposer = disposer
    }
}

// MARK: - If needed cache
public extension AVMediaCache {
    
    func mediaForAsset(url: URL, isPreload: Bool = false) -> AVURLAsset {
        
        lock()
        var asset: AVURLAsset
        
        // cache complete
        if let fileURL = AVMediaDataStorage.shared.completeFileURLWithURL(url) {
            asset = AVURLAsset(url: fileURL)
            unlock()
            return asset
        }
        
        asset = AVURLAsset(url: url.av.proxyURL())
        if url.av.canProxy() {
            
            // set delegate
            let delegate = AVMediaResourceLoader(url: url)
            asset.resourceLoader.setDelegate(delegate, queue: DispatchQueue.main)
            asset.mediaCacheLoader = delegate
            
            // cache resource
            var internalProxies = [AVMediaResourceProxy]()
            let internalProxy = AVMediaResourceProxy(url: url, isPreload: isPreload, target: delegate)
            internalProxies.append(internalProxy)
            if var resourceProxies = currentReousrces[url] {
                resourceProxies.append(contentsOf: internalProxies)
                currentReousrces[url] = resourceProxies
            } else {
                currentReousrces[url] = internalProxies
            }
        }
        unlock()
        return asset
    }
    
    func mediaForPlayerItem(url: URL, isPreload: Bool = false) -> AVPlayerItem {
        
        AVPlayerItem(asset: mediaForAsset(url: url, isPreload: isPreload))
    }
}

// MARK: - Notification
extension AVMediaCache {
    
    @objc private func applicationDidEnterBackground(_ notif: Notification) {
        clearInvaildProxies()
        limitCacheIfItNeeded()
    }
    
    @objc private func applicationMemoryWarningNotification(_ notif: Notification) {
        clearInvaildProxies()
        limitCacheIfItNeeded()
    }
    
    private func clearInvaildProxies() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lock()
            let currentReousrces = self.currentReousrces
            for (url, internalProxies) in currentReousrces {
                let internalProxies = internalProxies.compactMap({ $0.target == nil ? nil : $0 })
                self.currentReousrces[url] = internalProxies.isEmpty ? nil : internalProxies
            }
            self.unlock()
        }
    }
}

// MARK: - NSLocking
extension AVMediaCache {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
