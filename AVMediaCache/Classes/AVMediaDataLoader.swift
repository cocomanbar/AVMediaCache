//
//  AVMediaDataLoader.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDataLoadDelegate: NSObjectProtocol {
    
    func dataLoader(_ loader: AVMediaDataLoader, didFailWithError error: Error)
    func dataLoader(_ loader: AVMediaDataLoader, didChangeProgress progress: Double)
}

class AVMediaDataLoader: NSObject {
    
    public weak var delegate: AVMediaDataLoadDelegate?
    public private(set) var progress: Double = 0
    public private(set) var request: AVMediaDataRequest
    
    private(set) var continued: Bool = true
    private(set) var loadedLength: Int64 = 0
    private(set) var dataReader: AVMediaDataReader?
    
    public init(_ request: AVMediaDataRequest) {
        
        self.request = request
        self.dataReader = AVMediaDataReader(request)
    }
    
    deinit {
        close()
    }
    
    public func close() {
        dataReader?.close()
        dataReader = nil
    }
    
    public func prepare() {
        dataReader?.delegate = self
        dataReader?.prepare()
    }
    
    public func error() -> Error? {
        dataReader?.error
    }
    
    public func isPrepared() -> Bool {
        dataReader?.isPrepared ?? false
    }
    
    public func isFinished() -> Bool {
        dataReader?.isFinished ?? false
    }
    
    public func isClosed() -> Bool {
        dataReader?.isClosed ?? false
    }
    
}

extension AVMediaDataLoader: AVMediaDataReaderDelegate {
    
    func dataReaderDidPrepare(_ reader: AVMediaDataReader) {
        readData()
    }
    
    func dataReaderHasAvailableData(_ reader: AVMediaDataReader) {
        readData()
    }
    
    func dataReader(_ reader: AVMediaDataReader, didFailWithError error: Error) {
        readData()
    }
    
    func readData() {
        
        guard let dataReader = dataReader else { return }
        
        while continued {
            autoreleasepool {
                let data = dataReader.readDataOfLength(1 * 1024 * 1024)
                if dataReader.isFinished {
                    progress = 1.0
                    delegate?.dataLoader(self, didChangeProgress: progress)
                    continued = false
                } else if let _ = data {
                    loadedLength = dataReader.readedLength
                    if let contentLength = dataReader.response?.contentLength {
                        progress = Double(loadedLength / contentLength)
                    }
                    delegate?.dataLoader(self, didChangeProgress: progress)
                } else {
                    if let error = dataReader.error {
                        delegate?.dataLoader(self, didFailWithError: error)
                        continued = false
                    } else {
                        // waiting loading
                    }
                }
            }
        }
    }
}
