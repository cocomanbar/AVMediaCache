//
//  URLResponse.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/21.
//

import Foundation

extension URLResponse: AVMediaCacheCompatible {}

extension AVMediaCacheWrapper where Base: URLResponse {
    
    func byteRangeAccessSupported() -> Bool {
        
        if let value = value(allHeaderFields: "Content-Range"), !value.isEmpty {
            return true
        }
        
        return false
    }
    
    func totalLength() -> Int64 {
        
        if let value = value(allHeaderFields: "Content-Length"), let length = Int64(value) {
            return length
        }
        
        return base.expectedContentLength
    }
    
    func value(allHeaderFields fieldKey: String) -> String? {
        
        guard let response = base as? HTTPURLResponse else { return nil }
        
        if let value = response.allHeaderFields[fieldKey] {
            return value as? String
        }
        
        if let value = response.allHeaderFields[fieldKey.lowercased()] {
            return value as? String
        }
        
        return nil
    }
}
