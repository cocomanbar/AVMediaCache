//
//  AVMediaDataReader.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDataReaderDelegate: NSObjectProtocol {
    
    func dataReaderDidPrepare(_ reader: AVMediaDataReader)
    func dataReaderHasAvailableData(_ reader: AVMediaDataReader)
    func dataReader(_ reader: AVMediaDataReader, didFailWithError error: Error)
}

class AVMediaDataReader: NSObject {
    
    weak var delegate: AVMediaDataReaderDelegate?
    
    private(set) var error: Error?
    
    private(set) var isPrepared: Bool = false
    private(set) var isFinished: Bool = false
    private(set) var isClosed: Bool = false
    
    private(set) var readedLength: Int64 = 0
    private(set) var progress: Double = 0
    
    private(set) var request: AVMediaDataRequest
    private(set) var response: AVMediaDataResponse?
    
    private var calledPrepare = false
    private var unit: AVMediaDataUnit?
    private var sourceManager: AVMediaDataSourceManager?
    
    private lazy var coreLock: NSRecursiveLock = {
        let lock = NSRecursiveLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    private var delegateQueue: DispatchQueue
    private var responseQueue: DispatchQueue
    
    // MARK: - Init
    
    init(_ request: AVMediaDataRequest) {
        
        self.unit = AVMediaDataUnitPool.shared.unitWithURL(request.url)
        self.delegateQueue = DispatchQueue(label: "AVMediaCache_delegateQueue", qos: DispatchQoS.default)
        self.responseQueue = DispatchQueue(label: "AVMediaCache_internalDelegateQueue", qos: DispatchQoS.default)
        
        // update
        let totalLength: Int64 = unit?.totalLength ?? 0
        self.request = request.newRequestWithTotalLength(totalLength)
    }
    
    deinit {
        
    }
    
    
    func prepare() {
        
        lock()
        if isClosed || calledPrepare {
            unlock()
            return
        }
        calledPrepare = true
        prepareSourceManager()
        unlock()
    }
    
    func close() {
        
        lock()
        if isClosed {
            unlock()
            return
        }
        isClosed = true
        sourceManager?.close()
        unit?.workingRelease()
        unit = nil
        unlock()
    }
    
    func readDataOfLength(_ length: Int64?) -> Data? {
        
        lock()
        if isClosed || isFinished || self.error != nil {
            unlock()
            return nil
        }
        let data: Data? = sourceManager?.readDataOfLength(length)
        if let data = data, data.count > 0 {
            readedLength += Int64(data.count)
            if let contentLength = response?.contentLength, contentLength > 0 {
                progress = Double(readedLength / contentLength)
            }
        }
        if sourceManager?.isFinished ?? false {
            isFinished = true
            close()
        }
        unlock()
        return data
    }
    
    // MARK: - Private
    
    private func prepareSourceManager() {
        
        let range = request.range
        var fileSources = [AVMediaDataFileSource]()
        var networkSources = [AVMediaDataNetworkSource]()
        var min = range.start
        let max = range.end
        if let unitItems = unit?.allItems(), !unitItems.isEmpty {
            for item in unitItems {
                var itemMin = item.offset
                var itemMax = item.offset + item.length - 1
                if itemMax < min || itemMin > max {
                    continue
                }
                if min > itemMin {
                    itemMin = min
                }
                if max < itemMax {
                    itemMax = max
                }
                min = itemMax + 1
                let range = AVRange(start: item.offset, end: item.offset + item.length - 1)
                let readRange = AVRange(start: itemMin - item.offset, end: itemMax - item.offset)
                let source = AVMediaDataFileSource(item.absolutePath, range: range, readRange: readRange)
                fileSources.append(source)
            }
        }
        fileSources = fileSources.sorted(by: { source1, source2 in
            if source1.range.start < source2.range.start {
                return true
            }
            return false
        })
        var offset = range.start
        var length = range.isFullRange() ? range.length() : (range.end - range.start + 1)
        for source in fileSources {
            let delta = source.range.start + source.readRange.start - offset
            if delta > 0 {
                let range = AVRange(start: offset, end: offset + delta - 1)
                let request = request.newRequestWithRange(range)
                let networkSource = AVMediaDataNetworkSource(request)
                networkSources.append(networkSource)
                offset += delta
                length -= delta
            }
            offset += source.readRange.length()
            length -= source.readRange.length()
        }
        if length > 0 {
            let range = AVRange(start: offset, end: range.end)
            let request = request.newRequestWithRange(range)
            let networkSource = AVMediaDataNetworkSource(request)
            networkSources.append(networkSource)
        }
        var sources = [AVMediaDataSource]()
        sources.append(contentsOf: fileSources)
        sources.append(contentsOf: networkSources)
        sourceManager = AVMediaDataSourceManager(sources, delegate: self, delegateQueue: responseQueue)
        sourceManager?.prepare()
    }
    
    private func callbackForPrepared() {
        if isClosed || isPrepared {
            return
        }
        if let sourceManager = sourceManager, sourceManager.isPrepared, let unit = unit, unit.totalLength > 0 {
            let totalLength = unit.totalLength
            let range = AVRangeUtil.rangeWithEnsureLength(request.range, ensureLength: totalLength)
            let header = AVRangeUtil.fillRangeToResponseHeaders(range, header: unit.responseHeaders, totalLength: totalLength)
            self.response = AVMediaDataResponse(url: request.url, header: header)
            isPrepared = true
            delegateQueue.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.dataReaderDidPrepare(self)
            }
        }
    }
    
}

// MARK: - AVMediaDataSourceManagerDelegate
extension AVMediaDataReader: AVMediaDataSourceManagerDelegate {
    
    func sourceManagerDidPrepare(_ sourceManager: AVMediaDataSourceManager) {
        lock()
        callbackForPrepared()
        unlock()
    }
    
    func sourceManagerHasAvailableData(_ sourceManager: AVMediaDataSourceManager) {
        lock()
        if isClosed {
            unlock()
            return
        }
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.dataReaderHasAvailableData(self)
        }
        unlock()
    }
    
    func sourceManager(_ sourceManager: AVMediaDataSourceManager, didFailWithError error: Error) {
        lock()
        if isClosed || self.error != nil {
            unlock()
            return
        }
        self.error = error
        close()
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.dataReader(self, didFailWithError: error)
        }
        unlock()
    }
    
    func sourceManager(_ sourceManager: AVMediaDataSourceManager, didReceiveResponse response: AVMediaDataResponse?) {
        lock()
        if let header = response?.header, let totalLength = response?.totalLength {
            unit?.updateResponseHeaders(header, totalLength: totalLength)
        }
        callbackForPrepared()
        unlock()
    }
    
}

// MARK: - NSLocking
extension AVMediaDataReader: NSLocking {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
