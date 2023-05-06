//
//  AVMediaCachePreloader.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/5/1.
//

import UIKit

public enum AVMediaCachePreloadState: Int {
    case notFound
    case waiting
    case loading
    case finished
}

public protocol AVMediaCachePreloaderDelegate: NSObjectProtocol {
    
    func mediaPreload(_ preLoader: AVMediaCachePreloader, didCompleteUrl: URL, error: Error?)
}

public class AVMediaCachePreloader: NSObject {
    
    public var preloadLength: Int64 = 5 * 1024 * 1024
    public weak var delegate: AVMediaCachePreloaderDelegate?
    
    public private(set) var URLs = [URL]()
    public private(set) var URLStates = [URL: AVMediaCachePreloadState]()
    
    private var dataLoader: AVMediaDataLoader?
    private var internalQueue: DispatchQueue
    private var working: Bool
    
    public override init() {
        
        self.working = false
        self.internalQueue = DispatchQueue(label: "AVMediaCachePreloader_internalQueue", qos: .default)
        super.init()
    }
    
    public func preloadStateForUrl(_ url: URL?) -> AVMediaCachePreloadState {
        guard let url = url else { return .notFound }
        let state = URLStates[url] ?? .notFound
        return state
    }
    
    public func preloadUrls(_ urls: [URL]?) {
        guard let urls = urls else { return }
        
        internalQueue.async { [weak self] in
            guard let self = self else { return }
            for url in urls {
                if !url.av.canProxy() {
                    continue
                }
                if self.URLs.contains(url) || (self.URLStates[url] ?? .notFound) != .notFound {
                    continue
                }
                self.URLs.append(url)
                self.URLStates[url] = .waiting
            }
        }
        
        preloadNextIfNeeded()
    }
    
    public func clearIfNeeded() {
        
        internalQueue.async { [weak self] in
            guard let self = self else { return }
            self.URLs.removeAll()
            self.URLStates.removeAll()
            self.dataLoader?.close()
            self.dataLoader = nil
            self.working = false
        }
    }
    
    func preloadNextIfNeeded() {
        
        internalQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let url = self.URLs.first else {
                self.working = false
                return
            }
            self.working = true
            self.URLs.removeFirst()
            let request = AVMediaDataRequest(url: url, header: nil)
            self.dataLoader = AVMediaDataLoader(request)
            self.dataLoader?.delegate = self
            self.dataLoader?.prepare()
        }
    }
}

extension AVMediaCachePreloader: AVMediaDataLoadDelegate {
    
    func dataLoader(_ loader: AVMediaDataLoader, didFailWithError error: Error) {
        internalQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.mediaPreload(self, didCompleteUrl: loader.request.url, error: error)
            self.preloadNextIfNeeded()
        }
    }
    
    func dataLoader(_ loader: AVMediaDataLoader, didChangeProgress progress: Double) {
        internalQueue.async { [weak self] in
            guard let self = self else { return }
            let url = loader.request.url
            let item = AVMediaCache.shared.cacheItemWithURL(url)
            if item?.cacheLength ?? 0 >= self.preloadLength {
                loader.close()
                loader.delegate = nil
                self.dataLoader = nil
                self.delegate?.mediaPreload(self, didCompleteUrl: loader.request.url, error: nil)
                self.preloadNextIfNeeded()
            }
        }
    }
}
