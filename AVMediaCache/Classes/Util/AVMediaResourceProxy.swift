//
//  AVMediaResourceProxy.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/27.
//

import Foundation

public struct AVMediaResourceProxy {
    
    public var url: URL
    public var isPreload = false
    public weak var target: AnyObject?
    
    public init(url: URL, isPreload: Bool = false, target: AnyObject? = nil) {
        self.url = url
        self.isPreload = isPreload
        self.target = target
    }
    
    public func valid() -> Bool {
        target != nil
    }
    
    public func inValid() -> Bool {
        !valid()
    }
}
