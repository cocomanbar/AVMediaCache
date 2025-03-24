//
//  AVMediaDataUnit.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDataUnitDelegate: NSObjectProtocol {
    
    func mediaCacheUnitChangeMetaData(_ unit: AVMediaDataUnit, forceArchive: Bool)
}

class AVMediaDataUnit: NSObject {
    
    weak var delegate: AVMediaDataUnitDelegate?
    
    private(set) var url: URL?
    private(set) var key: String?
    private(set) var responseHeaders: [String: String]?
    
    private(set) var totalLength: Int64 = 0
    private(set) var createTimeInterval: TimeInterval = 0
    
    private(set) var error: Error?
    private(set) var workingCount: Int = 0
    
    private var unitItemsInternal: [AVMediaDataUnitItem] = [AVMediaDataUnitItem]()
    private var lockingUnitItems: [[AVMediaDataUnitItem]] = [[AVMediaDataUnitItem]]()
    
    private lazy var coreLock: NSRecursiveLock = {
        let lock = NSRecursiveLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    // MARK: - Init
     
    private override init() {}
    
    init(_ url: URL) {
        self.url = url
        self.key = AVMediaURLUtil.shared.keyWithURL(url: url)
        self.createTimeInterval = NSDate().timeIntervalSince1970
        
        super.init()
        commonInit()
    }
    
    required init(from decoder: Decoder) throws {
        super.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(URL.self, forKey: .url)
        self.key = try container.decode(String.self, forKey: .key)
        self.totalLength = try container.decode(Int64.self, forKey: .totalLength)
        self.responseHeaders = try container.decode([String: String].self, forKey: .responseHeaders)
        self.unitItemsInternal = try container.decode([AVMediaDataUnitItem].self, forKey: .unitItemsInternal)
        self.createTimeInterval = try container.decode(Double.self, forKey: .createTimeInterval)
        
        commonInit()
    }

    private func commonInit() {
        defer {
            unlock()
        }
        lock()
        
        // remove invalid items
        if !unitItemsInternal.isEmpty {
            var removal = [AVMediaDataUnitItem]()
            for value in unitItemsInternal {
                if value.length == 0 {
                    AVMediaPathUtil.deleteFileAtPath(value.absolutePath)
                    removal.append(value)
                }
            }
            if !removal.isEmpty {
                unitItemsInternal = unitItemsInternal.filter({ !removal.contains($0) })
            }
        }
        // sort items
        sortUnitItems()
    }
    
    private func sortUnitItems() {
        defer {
            unlock()
        }
        lock()
        
        unitItemsInternal = unitItemsInternal.sorted { unitItem1, unitItem2 in
            if unitItem1.offset < unitItem2.offset {
                return true
            } else if (unitItem1.offset == unitItem2.offset) && (unitItem1.length > unitItem2.length) {
                return true
            }
            return false
        }
    }
    
    
    func allItems() -> [AVMediaDataUnitItem] {
        defer {
            unlock()
        }
        lock()
        
        var items = [AVMediaDataUnitItem]()
        if !unitItemsInternal.isEmpty {
            for item in unitItemsInternal {
                if let item = item.copy() as? AVMediaDataUnitItem {
                    items.append(item)
                }
            }
        }
        return items
    }
    
    func insertUnitItem(_ unitItem: AVMediaDataUnitItem) {
        defer {
            unlock()
        }
        lock()
        
        unitItemsInternal.append(unitItem)
        sortUnitItems()
        delegate?.mediaCacheUnitChangeMetaData(self, forceArchive: false)
    }
    
    func updateResponseHeaders(_ responseHeaders: [String: String], totalLength: Int64) {
        defer {
            unlock()
        }
        lock()
        
        var needUpdate = false
        let whiteList: [String] = ["Accept-Ranges", "Connection", "Content-Type", "Server"]
        var headers = [String: String]()
        for key in whiteList {
            headers[key] = responseHeaders[key]
        }
        if self.totalLength != totalLength {
            self.totalLength = totalLength
            needUpdate = true
        }
        if let old_responseHeaders = self.responseHeaders, old_responseHeaders != headers {
            self.responseHeaders = headers
            needUpdate = true
        } else {
            self.responseHeaders = headers
            needUpdate = true
        }
        if needUpdate {
            delegate?.mediaCacheUnitChangeMetaData(self, forceArchive: false)
        }
    }
    
    func fileURL() -> URL? {
        defer {
            unlock()
        }
        lock()
        
        var fileURL: URL?
        if let item = unitItemsInternal.first,
           item.offset == 0, item.length > 0, item.length == totalLength {
            fileURL = NSURL(fileURLWithPath: item.absolutePath) as URL
        }
        return fileURL
    }
    
    func cacheLength() -> Int64 {
        defer {
            unlock()
        }
        lock()
        
        var length: Int64 = 0
        if !unitItemsInternal.isEmpty {
            for item in unitItemsInternal {
                length += item.length
            }
        }
        return length
    }
    
    func validLength() -> Int64 {
        defer {
            unlock()
        }
        lock()
        
        var offset: Int64 = 0
        var length: Int64 = 0
        for item in unitItemsInternal {
            let invalidLength = max(offset - item.offset, 0)
            let vaildLength   = max(item.length - invalidLength, 0)
            offset = max(offset, item.offset + item.length)
            length += vaildLength
        }
        return length
    }
    
    func lastItemCreateInterval() -> TimeInterval {
        defer {
            unlock()
        }
        lock()
        
        var timeInterval = createTimeInterval
        if !unitItemsInternal.isEmpty {
            for item in unitItemsInternal {
                if item.createTimeInterval > timeInterval {
                    timeInterval = item.createTimeInterval
                }
            }
        }
        return timeInterval
    }
    
    func workingRetain() {
        defer {
            unlock()
        }
        lock()
        
        workingCount += 1
    }
    
    func workingRelease() {
        defer {
            unlock()
        }
        lock()
        
        workingCount -= 1
        let needUpdate = mergeFilesIfNeeded()
        if needUpdate {
            delegate?.mediaCacheUnitChangeMetaData(self, forceArchive: true)
        }
    }
    
    func deleteFiles() {
        defer {
            unlock()
        }
        lock()
        
        guard let url = url else { return }
        let path = AVMediaPathUtil.directoryPathWithURL(url)
        AVMediaPathUtil.deleteDirectoryAtPath(path)
    }
    
    func mergeFilesIfNeeded() -> Bool {
        defer {
            unlock()
        }
        lock()
        
        if workingCount > 0 || totalLength == 0 || unitItemsInternal.isEmpty {
            return false
        }
        guard let path = AVMediaPathUtil.completeFilePathWithURL(url) else {
            return false
        }
        guard let absolutePath = unitItemsInternal.first?.absolutePath, absolutePath != path else {
            return false
        }
        let validLength = validLength()
        if totalLength != validLength {
            return false
        }
        // start merge
        var err: Error?
        var offset: Int64 = 0
        AVMediaPathUtil.deleteFileAtPath(path)
        AVMediaPathUtil.createFileAtPath(path)
        let writingHandle = FileHandle(forWritingAtPath: path)
        for unitItem in unitItemsInternal {
            if let _ = err {
                break
            }
            assert(offset >= unitItem.offset, "invaild unit item.")
            if offset >= (unitItem.offset + unitItem.length) {
                continue
            }
            let readingHandle = FileHandle(forReadingAtPath: unitItem.absolutePath)
            do {
                let _toOffset: UInt64 = UInt64(offset - unitItem.offset)
                if #available(iOS 13.0, *) {
                    try readingHandle?.seek(toOffset: _toOffset)
                } else {
                    readingHandle?.seek(toFileOffset: _toOffset)
                }
            } catch {
                err = error
            }
            if let _ = err {
                break
            }
            var execute: Bool = true
            while execute {
                autoreleasepool {
                    var data: Data?
                    do {
                        if #available(iOS 13.4, *) {
                            data = try readingHandle?.read(upToCount: 1 * 1024 * 1024)
                        } else {
                            data = readingHandle?.readData(ofLength: 1 * 1024 * 1024)
                        }
                    } catch {
                        err = error
                    }
                    guard let data = data, !data.isEmpty else {
                        execute = false
                        return
                    }
                    do {
                        if #available(iOS 13.4, *) {
                            try writingHandle?.write(contentsOf: data)
                        } else {
                            writingHandle?.write(data)
                        }
                    } catch {
                        err = error
                    }
                }
            }
            do {
                if #available(iOS 13.0, *) {
                    try readingHandle?.close()
                } else {
                    readingHandle?.closeFile()
                }
            } catch {
                err = error
            }
            offset = unitItem.offset + unitItem.length
        }
        do {
            if #available(iOS 13.0, *) {
                try writingHandle?.synchronize()
                try writingHandle?.close()
            } else {
                writingHandle?.synchronizeFile()
                writingHandle?.closeFile()
            }
        } catch {
            err = error
        }
        if let _ = err {
            return false
        }
        let fileSize = AVMediaPathUtil.sizeAtPath(path)
        if fileSize != totalLength {
            AVMediaPathUtil.deleteFileAtPath(path)
            return false
        }
        let item = AVMediaDataUnitItem(path: path, offset: 0)
        for unitItem in unitItemsInternal {
            AVMediaPathUtil.deleteFileAtPath(unitItem.absolutePath)
        }
        unitItemsInternal.removeAll()
        unitItemsInternal.append(item)
        return true
    }
}

// MARK: - Codable
extension AVMediaDataUnit: Codable {
    
    enum CodingKeys: String, CodingKey {
        case url = "url"
        case key = "key"
        case totalLength = "totalLength"
        case responseHeaders = "responseHeaders"
        case unitItemsInternal = "unitItemsInternal"
        case createTimeInterval = "createTimeInterval"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.url, forKey: .url)
        try container.encode(self.key, forKey: .key)
        try container.encode(self.totalLength, forKey: .totalLength)
        try container.encode(self.responseHeaders, forKey: .responseHeaders)
        try container.encode(self.unitItemsInternal, forKey: .unitItemsInternal)
        try container.encode(self.createTimeInterval, forKey: .createTimeInterval)
    }
}

// MARK: - NSLocking
extension AVMediaDataUnit: NSLocking {
    
    func lock() {
        coreLock.lock()
        if !unitItemsInternal.isEmpty {
            lockingUnitItems.append(unitItemsInternal)
            for item in unitItemsInternal {
                item.lock()
            }
        }
    }
    
    func unlock() {
        coreLock.unlock()
        if !lockingUnitItems.isEmpty {
            let unitItemsInternal = lockingUnitItems.removeLast()
            if !unitItemsInternal.isEmpty {
                for item in unitItemsInternal {
                    item.unlock()
                }
            }
        }
    }
}
