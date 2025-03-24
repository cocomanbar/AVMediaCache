//
//  AVMediaDataNetworkSource.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDataNetworkSourceDelegate: NSObjectProtocol {
    
    func networkSourceDidPrepare(_ source: AVMediaDataNetworkSource)
    func networkSourceHasAvailableData(_ source: AVMediaDataNetworkSource)
    func networkSourceDidFinisheDownload(_ source: AVMediaDataNetworkSource)
    func networkSource(_ source: AVMediaDataNetworkSource, didFailWithError error: Error)
}

class AVMediaDataNetworkSource: NSObject, AVMediaDataSource {
    
    private(set) var error: Error?
    
    private(set) var isPrepared: Bool = false
    private(set) var isFinished: Bool = false
    private(set) var isClosed: Bool = false
    
    private(set) var range: AVRange
    private(set) var readedLength: Int64 = 0
    
    private(set) var request: AVMediaDataRequest
    private(set) var response: AVMediaDataResponse?
    
    private weak var delegate: AVMediaDataNetworkSourceDelegate?
    private var delegateQueue: DispatchQueue?
    
    private lazy var coreLock: NSLock = {
        let lock = NSLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    private var readingHandle: FileHandle?
    private var writingHandle: FileHandle?
    
    private var unitItem: AVMediaDataUnitItem?
    private var downlaodTask: URLSessionTask?
    
    private lazy var downloadLength: Int64 = 0
    private lazy var downloadCalledComplete: Bool = false
    private lazy var callHasAvailableData: Bool = false
    private lazy var calledPrepare: Bool = false
    
    // MARK: - Init
    
    init(_ reqeust: AVMediaDataRequest) {
        self.request = reqeust
        self.range = reqeust.range
        
        super.init()
    }
    
    func prepareDelegate(_ delegate: AVMediaDataNetworkSourceDelegate, delegateQueue: DispatchQueue) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue
    }
    
    func prepare() {
        defer {
            unlock()
        }
        lock()
        
        if isClosed || calledPrepare{
            return
        }
        calledPrepare = true
        downlaodTask = AVMediaDownload.download.downloadWithRequest(request, delegate: self)
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
        if !downloadCalledComplete {
            downlaodTask?.cancel()
            downlaodTask = nil
        }
        destoryReadingHandle()
        destoryWritingHandle()
    }
    
    func readDataOfLength(_ length: Int64?) -> Data? {
        
        guard let length = length, length > 0 else { return nil }
        
        defer {
            unlock()
        }
        lock()
        
        var data: Data?
        var err: Error?
        
        if isClosed || isFinished || error != nil {
            return data
        }
        if readedLength >= downloadLength {
            if downloadCalledComplete {
                destoryReadingHandle()
            } else {
                callHasAvailableData = true
            }
            return data
        }
        do {
            let length: Int = Int(min(downloadLength - readedLength, length))
            if #available(iOS 13.4, *) {
                data = try readingHandle?.read(upToCount: length)
            } else {
                data = readingHandle?.readData(ofLength: length)
            }
        } catch {
            err = error
        }
        if let err = err {
            let error = NSError(domain: ErrorDomian,
                                code: ErrorCode,
                                userInfo: [NSLocalizedDescriptionKey : err.localizedDescription])
            callbackForFailed(error)
            return data
        }
        if let data = data {
            readedLength += Int64(data.count)
            if let response = response, let range = response.contentRange, readedLength >= range.length() {
                isFinished = true
                destoryReadingHandle()
            }
        }
        return data
    }
    
    private func destoryReadingHandle() {
        guard let readingHandle = readingHandle else { return }
        do {
            if #available(iOS 13.0, *) {
                try readingHandle.close()
            } else {
                readingHandle.closeFile()
            }
        } catch {
            
        }
        self.readingHandle = nil
    }
    
    private func destoryWritingHandle() {
        guard let writingHandle = writingHandle else { return }
        do {
            if #available(iOS 13.0, *) {
                try writingHandle.synchronize()
                try writingHandle.close()
            } else {
                writingHandle.synchronizeFile()
                writingHandle.closeFile()
            }
        } catch {
            
        }
        self.writingHandle = nil
    }
    
    private func callbackForPrepared() {
        if isClosed || isPrepared {
            return
        }
        isPrepared = true
        
        guard let delegate = delegate, let delegateQueue = delegateQueue else { return }
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            delegate.networkSourceDidPrepare(self)
        }
    }
    
    private func callbackForHasAvailableData() {
        if isClosed || !callHasAvailableData {
            return
        }
        callHasAvailableData = false
        
        guard let delegate = delegate, let delegateQueue = delegateQueue else { return }
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            delegate.networkSourceHasAvailableData(self)
        }
    }
    
    private func callbackForFailed(_ error: Error) {
        if isClosed || self.error != nil {
            return
        }
        self.error = error
        
        guard let delegate = delegate, let delegateQueue = delegateQueue else { return }
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            delegate.networkSource(self, didFailWithError: error)
        }
    }
}

extension AVMediaDataNetworkSource: AVMediaDownloadDelegate {
    
    func mediaDownload(_ download: AVMediaDownload, didCompleteError error: Error?) {
        defer {
            unlock()
        }
        lock()
        
        downloadCalledComplete = true
        destoryWritingHandle()
        if isClosed {
            // not anything to do
        } else if self.error != nil {
            // not anything to do
        } else if let error = error as? NSError {
            if error.code != URLError.cancelled.rawValue {
                callbackForFailed(error)
            } else {
                // not anything to do
            }
        } else if let contentRange = response?.contentRange, downloadLength >= contentRange.length() {
            guard let delegate = delegate, let delegateQueue = delegateQueue else {
                return
            }
            delegateQueue.async { [weak self] in
                guard let self = self else { return }
                delegate.networkSourceDidFinisheDownload(self)
            }
            
        } else {
            // not anything to do
        }
    }
    
    func mediaDownload(_ download: AVMediaDownload, didReceiveResponse response: AVMediaDataResponse?) {
        defer {
            unlock()
        }
        lock()
        
        if isClosed || self.error != nil {
            return
        }
        self.response = response
        let path = AVMediaPathUtil.filePathWithURL(request.url, offset: request.range.start)
        let unitItem = AVMediaDataUnitItem(path: path, offset: request.range.start)
        let unit = AVMediaDataUnitPool.shared.unitWithURL(request.url)
        unit?.insertUnitItem(unitItem)
        unit?.workingRelease()
        self.unitItem = unitItem
        self.writingHandle = FileHandle(forWritingAtPath: unitItem.absolutePath)
        self.readingHandle = FileHandle(forReadingAtPath: unitItem.absolutePath)
        
        callbackForPrepared()
    }
    
    func mediaDownload(_ download: AVMediaDownload, didReceiveData data: Data) {
        defer {
            unlock()
        }
        lock()
        
        if isClosed || self.error != nil {
            return
        }
        var err: Error?
        do {
            if #available(iOS 13.4, *) {
                try writingHandle?.write(contentsOf: data)
            } else {
                writingHandle?.write(data)
            }
        } catch {
            err = error
        }
        if let err = err {
            let error = NSError(domain: ErrorDomian,
                                code: ErrorCode,
                                userInfo: [NSLocalizedDescriptionKey : err.localizedDescription])
            callbackForFailed(error)
            if !downloadCalledComplete {
                downlaodTask?.cancel()
                downlaodTask = nil
            }
        } else {
            downloadLength += Int64(data.count)
            unitItem?.updateLength(downloadLength)
            callHasAvailableData = true
            callbackForHasAvailableData()
        }
    }
}

extension AVMediaDataNetworkSource: NSLocking {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
