//
//  AVMediaURLUtil.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

public typealias URLConvertKeyClosure = ((URL) -> URL)

class AVMediaURLUtil {
    
    var urlConvert: URLConvertKeyClosure?
    
    // MARK: - Init
    
    private init() {}
    
    static let shared = AVMediaURLUtil()
    
    // MARK: - Public
    
    func keyWithURL(url: URL) -> String {
        
        let url: URL = urlConvert?(url) ?? url
        return url.absoluteString.av.md5
    }
}
