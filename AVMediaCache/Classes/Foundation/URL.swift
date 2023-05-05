//
//  URL_.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/20.
//

import Foundation

extension URL: AVMediaCacheCompatibleValue {}
extension NSURL: AVMediaCacheCompatible {}

public extension AVMediaCacheWrapper where Base == URL {
    
    func canProxy() -> Bool {
        if base.isFileURL {
            return false
        }
        if isMP4() {
            return true
        }
        // TODO
        if isM3U8() {
            return false
        }
        return false
    }
    
    func proxyURL() -> URL {
        
        if canProxy() {
            let components = NSURLComponents(url: base, resolvingAgainstBaseURL: false)
            guard let scheme = components?.scheme, !scheme.hasPrefix(AVMediaCache.customSchemePrefix) else {
                return base
            }
            components?.scheme = AVMediaCache.customSchemePrefix + scheme
            guard let proxyURL = components?.url else { return base }
            return proxyURL
        }
        
        return base
    }
    
    func originalURL() -> URL {
        
        let components = NSURLComponents(url: base, resolvingAgainstBaseURL: false)
        guard let scheme = components?.scheme, scheme.hasPrefix(AVMediaCache.customSchemePrefix) else {
            return base
        }
        let index: String.Index = scheme.index(scheme.startIndex, offsetBy: AVMediaCache.customSchemePrefix.count)
        components?.scheme = String(scheme[index...])
        guard let originalURL = components?.url else { return base }
        return originalURL
    }
    
    func isM3U8() -> Bool {
        base.pathExtension.lowercased() == "m3u8"
    }
    
    func isMP4() -> Bool {
        base.pathExtension.lowercased() == "mp4"
    }
    
    func queryItems() -> [URLQueryItem]? {
        
        guard let components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems
    }
}

public extension AVMediaCacheWrapper where Base: NSURL {
    
    func proxyURL() -> NSURL {
        (base as URL).av.proxyURL() as NSURL
    }
    
    func originalURL() -> NSURL {
        (base as URL).av.originalURL() as NSURL
    }
    
    func isM3U8() -> Bool {
        (base as URL).av.isM3U8()
    }
    
    func isMP4() -> Bool {
        (base as URL).av.isMP4()
    }
    
    func queryItems() -> [NSURLQueryItem]? {
        (base as URL).av.queryItems() as? [NSURLQueryItem]
    }
}
