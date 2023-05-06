//
//  AVMediaResourceProxy.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/27.
//

import Foundation

public struct AVMediaResourceProxy {
    
    public var url: URL
    public weak var target: AnyObject?
    
    public init(url: URL, target: AnyObject? = nil) {
        self.url = url
        self.target = target
    }
    
    public func valid() -> Bool {
        target != nil
    }
    
    public func inValid() -> Bool {
        !valid()
    }
}
