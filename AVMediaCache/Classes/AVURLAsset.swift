//
//  AVURLAsset.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/21.
//

import Foundation
import AVFoundation

private var mediaCacheLoaderKey: Void?

extension AVURLAsset {
    
    var mediaCacheLoader: AVAssetResourceLoaderDelegate? {
        get {
            objc_getAssociatedObject(self, &mediaCacheLoaderKey) as? AVAssetResourceLoaderDelegate
        }
        set {
            objc_setAssociatedObject(self, &mediaCacheLoaderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
