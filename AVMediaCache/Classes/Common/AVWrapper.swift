//
//  AVWrapper.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/27.
//

import Foundation

public struct AVMediaCacheWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

public protocol AVMediaCacheCompatible: AnyObject {}
public protocol AVMediaCacheCompatibleValue {}

extension AVMediaCacheCompatible {
    public var av: AVMediaCacheWrapper<Self> {
        get { return AVMediaCacheWrapper(self) }
        set { }
    }
}

extension AVMediaCacheCompatibleValue {
    public var av: AVMediaCacheWrapper<Self> {
        get { return AVMediaCacheWrapper(self) }
        set { }
    }
}
