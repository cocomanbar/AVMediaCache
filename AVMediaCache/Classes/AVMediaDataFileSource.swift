//
//  AVMediaDataFileSource.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDataFileSourceDelegate: NSObjectProtocol {
    
    func fileSourceDidPrepare(_ source: AVMediaDataFileSource)
    func fileSource(_ source: AVMediaDataFileSource, didFailWithError error: Error)
}

class AVMediaDataFileSource: NSObject, AVMediaDataSource {
    
    private(set) var error: Error?
    
    private(set) var isPrepared: Bool = false
    private(set) var isFinished: Bool = false
    private(set) var isClosed: Bool = false
    
    private(set) var range: AVRange
    private(set) var readRange: AVRange
    
    private(set) var readedLength: Int64 = 0
    
    private var path: String
    
    weak private var delegate: AVMediaDataFileSourceDelegate?
    private var delegateQueue: DispatchQueue?
    
    private var readingHandle: FileHandle?
    
    private lazy var coreLock: NSLock = {
        let lock = NSLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    // MARK: - Init
    
    init(_ path: String, range: AVRange, readRange: AVRange) {
        
        self.path = path
        self.range = range
        self.readRange = readRange
        
        super.init()
    }
    
    deinit {
        
    }
    
    
    func prepareDelegate(_ delegate: AVMediaDataFileSourceDelegate, delegateQueue: DispatchQueue) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue
    }
    
    func prepare() {
        
        lock()
        if isPrepared {
            unlock()
            return
        }
        isPrepared = true
        readingHandle = FileHandle(forReadingAtPath: path)
        var err: Error?
        do {
            if #available(iOS 13.0, *) {
                try readingHandle?.seek(toOffset: UInt64(readRange.start))
            } else {
                readingHandle?.seek(toFileOffset: UInt64(readRange.start))
            }
        } catch {
            err = error
        }
        guard let delegate = delegate, let delegateQueue = delegateQueue else {
            unlock()
            return
        }
        if let err = err {
            let error = NSError(domain: ErrorDomian,
                                code: ErrorCode,
                                userInfo: [NSLocalizedDescriptionKey : err.localizedDescription])
            delegateQueue.async { [weak self] in
                guard let self = self else { return }
                delegate.fileSource(self, didFailWithError: error)
            }
        } else {
            delegateQueue.async { [weak self] in
                guard let self = self else { return }
                delegate.fileSourceDidPrepare(self)
            }
        }
        unlock()
    }
    
    func close() {
        lock()
        if isClosed {
            unlock()
            return
        }
        isClosed = true
        destoryReadingHandle()
        unlock()
    }
    
    func readDataOfLength(_ length: Int64?) -> Data? {
        lock()
        var err: Error?
        var data: Data?
        
        if isClosed || isFinished {
            unlock()
            return data
        }
        do {
            let readLength: Int = Int(readRange.length())
            if #available(iOS 13.4, *) {
                data = try readingHandle?.read(upToCount: readLength)
            } else {
                data = readingHandle?.readData(ofLength: readLength)
            }
        } catch {
            err = error
        }
        if let err = err {
            let error = NSError(domain: ErrorDomian,
                                code: ErrorCode,
                                userInfo: [NSLocalizedDescriptionKey : err.localizedDescription])
            callbackForFailed(error)
        } else {
            if let data = data {
                readedLength += Int64(data.count)
            }
            if readedLength >= readRange.length() {
                destoryReadingHandle()
                isFinished = true
            }
        }
        unlock()
        return data
    }
    
    // MARK: - Private
    
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
    
    private func callbackForFailed(_ error: Error) {
        if isClosed || self.error != nil {
            return
        }
        self.error = error
        
        guard let delegate = delegate, let delegateQueue = delegateQueue else { return }
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            delegate.fileSource(self, didFailWithError: error)
        }
    }
}

extension AVMediaDataFileSource: NSLocking {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
