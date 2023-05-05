//
//  Dictionary.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import Foundation

extension Dictionary: AVMediaCacheCompatibleValue {}

extension AVMediaCacheWrapper where Base == Dictionary<String, String> {
    
    // 解决用Charles抓包匹配问题大小写的调试问题
    func headerValueWithKey(_ key: String) -> String? {
        
        if let value = base[key] {
            return value
        }
        if let value = base[key.lowercased()] {
            return value
        }
        return nil
    }
}
