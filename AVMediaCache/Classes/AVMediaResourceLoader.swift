//
//  AVMediaResourceLoader.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit
import AVFoundation

class AVMediaResourceLoader: NSObject {
    
    private var url: URL
    
    // MARK: - Init
    
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        cancelLoading()
    }
    
    func startLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
    
        let url: URL = loadingRequest.request.url ?? url
        let requestedOffset: Int64 = loadingRequest.dataRequest?.requestedOffset ?? 0
        let requestedLength: Int64 = Int64(loadingRequest.dataRequest?.requestedLength ?? 0)
        var header: [String: String] = loadingRequest.request.allHTTPHeaderFields ?? [String: String]()
        let rangeValue = "bytes=\(requestedOffset)" + "-" + "\(requestedOffset + requestedLength - 1)"
        header["Range"] = rangeValue
        let dataRequest = AVMediaDataRequest(url: url.av.originalURL(), header: header)
        let reader = AVMediaDataReader(dataRequest)
        mediaReaders[reader] = loadingRequest
        mediaReadLengths[reader] = requestedLength
        reader.delegate = self
        reader.prepare()
    }
    
    func cancelLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        let mediaReaders = mediaReaders
        var reader: AVMediaDataReader?
        for element in mediaReaders {
            if element.value == loadingRequest {
                reader = element.key
                break
            }
        }
        if let reader = reader {
            reader.close()
            self.mediaReaders[reader] = nil
        }
    }
    
    func fillContentInformationResponse(_ reader: AVMediaDataReader) {
        guard let loadingRequest = mediaReaders[reader],
                let contentInformationRequest = loadingRequest.contentInformationRequest else {
            return
        }
        
        contentInformationRequest.contentType = reader.response?.contentType
        contentInformationRequest.contentLength = reader.response?.totalLength ?? 0
        contentInformationRequest.isByteRangeAccessSupported = reader.response?.contentRangeString != nil
    }
    
    func cancelLoading() {
        for element in mediaReaders {
            element.key.close()
        }
    }
    
    // MARK: - Lazy
    
    private lazy var mediaReaders: [AVMediaDataReader: AVAssetResourceLoadingRequest] = {
        [AVMediaDataReader: AVAssetResourceLoadingRequest]()
    }()
    
    private lazy var mediaReadLengths: [AVMediaDataReader: Int64] = {
        [AVMediaDataReader: Int64]()
    }()
}


// MARK: - AVMediaDataReaderDelegate
extension AVMediaResourceLoader: AVMediaDataReaderDelegate {
    
    func dataReaderDidPrepare(_ reader: AVMediaDataReader) {
        fillContentInformationResponse(reader)
    }
    
    func dataReaderHasAvailableData(_ reader: AVMediaDataReader) {
        let requestedLength = mediaReadLengths[reader]
        if let data = reader.readDataOfLength(requestedLength), !data.isEmpty {
            let loadingRequest = mediaReaders[reader]
            loadingRequest?.dataRequest?.respond(with: data)
            if reader.isFinished {
                mediaReaders[reader] = nil
                loadingRequest?.finishLoading()
            }
        }
    }
    
    func dataReader(_ reader: AVMediaDataReader, didFailWithError error: Error) {
        let loadingRequest = mediaReaders[reader]
        mediaReaders[reader] = nil
        loadingRequest?.finishLoading(with: error)
        
        // report error
        if let report = AVMediaCache.shared.reportClosure {
            let code = (error as NSError).code
            let domain = (error as NSError).domain
            var userInfo = (error as NSError).userInfo
            if userInfo[NSURLErrorKey] == nil {
                userInfo[NSURLErrorKey] = reader.request.url as NSURL
            }
            let error = NSError(domain: domain, code: code, userInfo: userInfo)
            DispatchQueue.main.async {
                report(error)
            }
        }
    }
}

// MARK: - AVAssetResourceLoaderDelegate
extension AVMediaResourceLoader: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        startLoadingRequest(loadingRequest)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        cancelLoadingRequest(loadingRequest)
    }
}
