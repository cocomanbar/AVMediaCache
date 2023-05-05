//
//  AVMediaPreloader.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/5/1.
//

import UIKit

public enum AVMediaPreloadState: Int {
    case notFound
    case waiting
    case loading
    case finished
}

public protocol AVMediaPreloadDelegate: NSObjectProtocol {
    
    func mediaPreload(_ preLoader: AVMediaPreloader, didCompleteUrl: URL, error: Error?)
}

public class AVMediaPreloader: NSObject {
    
    public var length: Int64 = 5 * 1024 * 1024
    
    public private(set) var URLs = [URL]()
    public private(set) var URLStates = [URL: AVMediaPreloadState]()
    
    public private(set) weak var delegate: AVMediaPreloadDelegate?
    
    private var dataLoader: AVMediaDataLoader?
    private var internalQueue: DispatchQueue
    private var working: Bool
    
    public init(_ delegate: AVMediaPreloadDelegate?) {
        
        self.working = false
        self.delegate = delegate
        self.internalQueue = DispatchQueue(label: "AVMediaCache_internalQueue", qos: .default)
    }
    
    public func preloadStateForUrl(_ url: URL?) -> AVMediaPreloadState {
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
            
            if self.working {
                return
            }
            guard let url = self.URLs.first else {
                return
            }
            self.URLs.removeFirst()
            let request = AVMediaDataRequest(url: url, header: nil)
            self.dataLoader = AVMediaDataLoader(request)
            self.dataLoader?.delegate = self
            self.dataLoader?.prepare()
        }
    }
}

extension AVMediaPreloader: AVMediaDataLoadDelegate {
    
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
            if item?.cacheLength ?? 0 >= self.length {
                loader.close()
                loader.delegate = nil
                self.dataLoader = nil
                self.delegate?.mediaPreload(self, didCompleteUrl: loader.request.url, error: nil)
                self.preloadNextIfNeeded()
            }
        }
    }
}
