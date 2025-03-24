//
//  AVMediaDataSourceManager.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDataSourceManagerDelegate: NSObjectProtocol {
    
    func sourceManagerDidPrepare(_ sourceManager: AVMediaDataSourceManager)
    func sourceManagerHasAvailableData(_ sourceManager: AVMediaDataSourceManager)
    func sourceManager(_ sourceManager: AVMediaDataSourceManager, didFailWithError error: Error)
    func sourceManager(_ sourceManager: AVMediaDataSourceManager, didReceiveResponse response: AVMediaDataResponse?)
}

class AVMediaDataSourceManager: NSObject, AVMediaDataSource {
    
    private(set) var error: Error?
    
    private(set) var isPrepared: Bool = false
    private(set) var isFinished: Bool = false
    private(set) var isClosed: Bool = false
    
    private(set) var range: AVRange
    private(set) var readedLength: Int64 = 0
    
    private var sources: [AVMediaDataSource]
    weak private var delegate: AVMediaDataSourceManagerDelegate?
    private var delegateQueue: DispatchQueue
    
    private var calledPrepare = false
    private var calledReceiveResponse = false
    
    private var currentSource: AVMediaDataSource?
    private var currentNetworkSource: AVMediaDataSource?
    
    private lazy var coreLock: NSLock = {
        let lock = NSLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    // MARK: - Init
    
    init(_ sources: [AVMediaDataSource], delegate: AVMediaDataSourceManagerDelegate, delegateQueue: DispatchQueue) {
        
        self.range = AVRange.InvaildRange
        self.sources = sources
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        
        super.init()
    }
    
    func prepare() {
        defer {
            unlock()
        }
        lock()
        
        if isClosed || calledPrepare {
            return
        }
        calledPrepare = true
        sources = sources.sorted(by: { source1, source2 in
            if source1.range.start < source2.range.start {
                return true
            }
            return false
        })
        
        for source in sources {
            if let source = source as? AVMediaDataFileSource {
                source.prepareDelegate(self, delegateQueue: delegateQueue)
            } else if let source = source as? AVMediaDataNetworkSource {
                source.prepareDelegate(self, delegateQueue: delegateQueue)
                if currentNetworkSource == nil {
                    currentNetworkSource = source
                }
            }
        }
                
        currentSource = sources.first
        currentSource?.prepare()
        currentNetworkSource?.prepare()
    }
    
    func close() {
        defer {
            unlock()
        }
        lock()
        
        if isClosed {
            return
        }
        isClosed = true
        for source in sources {
            source.close()
        }
    }
    
    func readDataOfLength(_ length: Int64?) -> Data? {
        defer {
            unlock()
        }
        lock()
        
        if isClosed || isFinished || self.error != nil {
            return nil
        }
        let data: Data? = currentSource?.readDataOfLength(length)
        if let data = data {
            readedLength += Int64(data.count)
        }
        if currentSource?.isFinished ?? false {
            currentSource = nextSource()
            if let currentSource = currentSource {
                if let currentSource = currentSource as? AVMediaDataFileSource {
                    currentSource.prepare()
                }
            } else {
                isFinished = true
            }
        }
        return data
    }
    
    // MARK: - Private
    
    private func nextSource() -> AVMediaDataSource? {
        guard let currentSource = currentSource else { return nil }
        let index: Int? = sources.firstIndex { source in
            source.hashValue == currentSource.hashValue
        }
        guard let index = index else { return nil }
        if index + 1 < sources.count {
            return sources[index + 1]
        }
        return nil
    }
    
    private func nextNetworkSource() -> AVMediaDataSource? {
        guard let currentNetworkSource = currentNetworkSource else { return nil }
        let index: Int? = sources.firstIndex { source in
            source.hashValue == currentNetworkSource.hashValue
        }
        guard let index = index else { return nil }
        for (i, source) in sources.enumerated() {
            if i <= index {
                continue
            }
            if let source = source as? AVMediaDataNetworkSource {
                return source
            }
        }
        return nil
    }
    
    private func callbackForPrepared() {
        if isClosed || isPrepared {
            return
        }
        isPrepared = true
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sourceManagerDidPrepare(self)
        }
    }
    
    private func callbackForHasAvailableData() {
        if isClosed {
            return
        }
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sourceManagerHasAvailableData(self)
        }
    }
    
    private func callbackForFailed(_ error: Error) {
        if isClosed || self.error != nil {
            return
        }
        self.error = error
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sourceManager(self, didFailWithError: error)
        }
    }
    
    private func callbackForReceiveResponse(_ response: AVMediaDataResponse?) {
        if isClosed || calledReceiveResponse {
            return
        }
        calledReceiveResponse = true
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.sourceManager(self, didReceiveResponse: response)
        }
    }
}

// MARK: - AVMediaDataFileSourceDelegate
extension AVMediaDataSourceManager: AVMediaDataFileSourceDelegate {
    
    func fileSourceDidPrepare(_ source: AVMediaDataFileSource) {
        defer {
            unlock()
        }
        lock()
        
        callbackForPrepared()
        callbackForHasAvailableData()
    }
    
    func fileSource(_ source: AVMediaDataFileSource, didFailWithError error: Error) {
        defer {
            unlock()
        }
        lock()
        
        callbackForFailed(error)
    }
}

// MARK: - AVMediaDataNetworkSourceDelegate
extension AVMediaDataSourceManager: AVMediaDataNetworkSourceDelegate {
    
    func networkSourceDidPrepare(_ source: AVMediaDataNetworkSource) {
        defer {
            unlock()
        }
        lock()
        
        callbackForPrepared()
        callbackForReceiveResponse(source.response)
    }
    
    func networkSourceHasAvailableData(_ source: AVMediaDataNetworkSource) {
        defer {
            unlock()
        }
        lock()
        
        callbackForHasAvailableData()
    }
    
    func networkSourceDidFinisheDownload(_ source: AVMediaDataNetworkSource) {
        defer {
            unlock()
        }
        lock()
        
        currentNetworkSource = nextNetworkSource()
        currentNetworkSource?.prepare()
    }
    
    func networkSource(_ source: AVMediaDataNetworkSource, didFailWithError error: Error) {
        defer {
            unlock()
        }
        lock()
        
        callbackForFailed(error)
    }
}


// MARK: - NSLocking
extension AVMediaDataSourceManager: NSLocking {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
