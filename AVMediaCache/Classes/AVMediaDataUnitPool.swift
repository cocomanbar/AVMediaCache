//
//  AVMediaDataUnitPool.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

class AVMediaDataUnitPool: NSObject {
    
    private lazy var expectArchiveIndex: Int64 = 0
    private lazy var actualArchiveIndex: Int64 = 0
    
    private lazy var coreLock: NSRecursiveLock = {
        let lock = NSRecursiveLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    private lazy var unitQueue: AVMediaDataUnitQueue = {
        let queue = AVMediaDataUnitQueue(AVMediaPathUtil.archivePath())
        return queue
    }()
    
    private lazy var archiveQueue: DispatchQueue = {
        DispatchQueue(label: "AVMediaCache_archiveQueue", qos: DispatchQoS.default)
    }()
    
    // MARK: - Init
    
    static let shared = AVMediaDataUnitPool()
    
    private override init() {
        super.init()
    
        let _ = unitQueue.allUnits().map { $0.delegate = self }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate(_:)),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive(_:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    
    func unitWithURL(_ url: URL?) -> AVMediaDataUnit? {
        
        guard let url = url, !url.absoluteString.isEmpty else { return nil }
        
        lock()
        let key = AVMediaURLUtil.shared.keyWithURL(url: url)
        var unit = self.unitQueue.unitWithKey(key)
        if unit == nil {
            unit = AVMediaDataUnit(url)
            unit?.delegate = self
            unitQueue.putUnit(unit)
            setNeedsArchive()
        }
        unit?.workingRetain()
        unlock()
        
        return unit
    }
    
    func deleteUnitWithURL(_ url: URL?) {
        
        guard let url = url, !url.absoluteString.isEmpty else { return }
        
        lock()
        let key = AVMediaURLUtil.shared.keyWithURL(url: url)
        if let unit = self.unitQueue.unitWithKey(key), unit.workingCount <= 0 {
            unit.deleteFiles()
            unitQueue.popUnit(unit)
            setNeedsArchive()
        }
        unlock()
    }
    
    func totalCacheLength() -> Int64 {
        
        lock()
        var length: Int64 = 0
        let _ = unitQueue.allUnits().map { length += $0.cacheLength() }
        unlock()
        return length
    }
    
    func totalCacheLengthWithCompleted(_ isCompleted: Bool) -> Int64 {
        
        lock()
        var length: Int64 = 0
        let allUnits = unitQueue.allUnits()
        for unit in allUnits {
            if let unitItem = unit.allItems().first {
                let ret = unitItem.offset == 0 && unitItem.length > 0 && unitItem.length == unit.totalLength
                if isCompleted {
                    if ret {
                        length += unit.totalLength
                    }
                } else {
                    if !ret {
                        length += unit.totalLength
                    }
                }
            }
        }
        unlock()
        return length
    }
    
    func cacheItemWithURL(_ url: URL?) -> AVMediaDataCacheItem? {

        lock()
        guard let url = url, !url.absoluteString.isEmpty else {
            unlock()
            return nil
        }
        let key = AVMediaURLUtil.shared.keyWithURL(url: url)
        guard let unit = unitQueue.unitWithKey(key) else {
            unlock()
            return nil
        }
        let cacheItemZones: [AVMediaDataCacheItemZone] = unit.allItems().map { unitItem in
            AVMediaDataCacheItemZone(offset: unitItem.offset, length: unitItem.length)
        }
        let cacheItem = AVMediaDataCacheItem(url: url, totalLength: unit.totalLength, cacheLength: unit.cacheLength(), vaildLength: unit.validLength(), zones: cacheItemZones)
        unlock()
        return cacheItem
    }
    
    func allCacheItem() -> [AVMediaDataCacheItem] {
        
        lock()
        let units = unitQueue.allUnits()
        let cacheItems = units.compactMap { unit in
            if let cacheItem = cacheItemWithURL(unit.url), !cacheItem.zones.isEmpty {
                return cacheItem
            }
            return nil
        }
        unlock()
        return cacheItems
    }
    
    func deleteUnitsWithLength(_ length: Int64) {
        
        if length <= 0 {
            return
        }
        
        lock()
        
        // ASC sort by lastCreateTime
        let units = unitQueue.allUnits().sorted { unit1, unit2 in
            unit1.lock()
            unit2.lock()
            let unit1_last_createTime: TimeInterval = unit1.lastItemCreateInterval()
            let unit2_last_createTime: TimeInterval = unit2.lastItemCreateInterval()
            if unit1_last_createTime < unit2_last_createTime {
                unit1.unlock()
                unit2.unlock()
                return true
            } else if unit1_last_createTime == unit2_last_createTime &&
                        unit1.createTimeInterval < unit2.createTimeInterval {
                unit1.unlock()
                unit2.unlock()
                return true
            }
            unit1.unlock()
            unit2.unlock()
            return false
        }
        
        var needArchive = false
        var currentLength: Int64 = 0
        
        for unit in units {
            if unit.workingCount <= 0 {
                unit.lock()
                currentLength += unit.cacheLength()
                unit.deleteFiles()
                unit.unlock()
                unitQueue.popUnit(unit)
                needArchive = true
            }
            if currentLength >= length {
                break
            }
        }
        
        if needArchive {
            setNeedsArchive()
        }
        
        unlock()
    }
    
    func deleteAllUnits() {
        
        lock()
        var needArchive = false
        let units = unitQueue.allUnits()
        for unit in units {
            if unit.workingCount <= 0 {
                unit.deleteFiles()
                unitQueue.popUnit(unit)
                needArchive = true
            }
        }
        if needArchive {
            setNeedsArchive()
        }
        unlock()
    }
    
    // MARK: - Private
    
    private func setNeedsArchive() {
        
        lock()
        expectArchiveIndex += 1
        let expectArchiveIndex = expectArchiveIndex
        unlock()
        archiveQueue.asyncAfter(deadline: .now() + 3.0) {
            self.lock()
            if self.expectArchiveIndex == expectArchiveIndex {
                self.archiveIfNeeded()
            }
            self.unlock()
        }
    }
    
    private func archiveIfNeeded() {
        
        lock()
        if expectArchiveIndex != actualArchiveIndex {
            actualArchiveIndex = expectArchiveIndex
            unitQueue.archive()
        }
        unlock()
    }
}

// MARK: - AVMediaDataUnitDelegate
extension AVMediaDataUnitPool: AVMediaDataUnitDelegate {
    
    func mediaCacheUnitChangeMetaData(_ unit: AVMediaDataUnit, forceArchive: Bool) {
        forceArchive ? archiveIfNeeded() : setNeedsArchive()
    }
}

// MARK: - Notification
extension AVMediaDataUnitPool {
    
    @objc private func applicationWillTerminate(_ notif: Notification) {
        archiveIfNeeded()
    }
    
    @objc private func applicationDidEnterBackground(_ notif: Notification) {
        archiveIfNeeded()
    }
    
    @objc private func applicationWillResignActive(_ notif: Notification) {
        archiveIfNeeded()
    }
}

extension AVMediaDataUnitPool: NSLocking {
    
    func lock() {
        coreLock.lock()
    }

    func unlock() {
        coreLock.unlock()
    }
}
