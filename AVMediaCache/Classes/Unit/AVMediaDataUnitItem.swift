//
//  AVMediaDataUnitItem.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

class AVMediaDataUnitItem: NSObject {
    
    private(set) var relativePath: String
    private(set) var absolutePath: String
    
    private(set) var offset: Int64 = 0
    private(set) var length: Int64 = 0
    
    private(set) var createTimeInterval: TimeInterval = 0
    
    private lazy var coreLock: NSRecursiveLock = {
        let lock = NSRecursiveLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    // MARK: - Init
    
    init(path: String, offset: Int64) {
        
        self.offset = offset
        self.createTimeInterval = NSDate().timeIntervalSince1970
        self.relativePath = AVMediaPathUtil.converToRelativePath(path)
        self.absolutePath = AVMediaPathUtil.converToAbsoultePath(relativePath)
        self.length = AVMediaPathUtil.sizeAtPath(absolutePath)
        
        super.init()
        commonInit()
    }
    
    required init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.offset = try container.decode(Int64.self, forKey: .offset)
        self.relativePath = try container.decode(String.self, forKey: .relativePath)
        self.createTimeInterval = try container.decode(Double.self, forKey: .createTimeInterval)
        self.absolutePath = AVMediaPathUtil.converToAbsoultePath(relativePath)
        self.length = AVMediaPathUtil.sizeAtPath(absolutePath)
        
        super.init()
        commonInit()
    }
    
    func commonInit() {
        
    }
    
    deinit {
        
    }
        
    func updateLength(_ length: Int64) {
        lock()
        self.length = length
        unlock()
    }
}

// MARK: - Codable
extension AVMediaDataUnitItem: Codable {
    
    enum CodingKeys: String, CodingKey {
        case offset = "offset"
        case relativePath = "relativePath"
        case createTimeInterval = "createTimeInterval"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.offset, forKey: .offset)
        try container.encode(self.relativePath, forKey: .relativePath)
        try container.encode(self.createTimeInterval, forKey: .createTimeInterval)
    }
}

// MARK: - NSCopying
extension AVMediaDataUnitItem: NSCopying {
    
    func copy(with zone: NSZone? = nil) -> Any {
        lock()
        let unitItem = AVMediaDataUnitItem(path: absolutePath, offset: offset)
        unitItem.relativePath = relativePath
        unitItem.absolutePath = absolutePath
        unitItem.createTimeInterval = createTimeInterval
        unitItem.offset = offset
        unitItem.length = length
        unlock()
        return unitItem
    }
}

// MARK: - NSLocking
extension AVMediaDataUnitItem: NSLocking {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
