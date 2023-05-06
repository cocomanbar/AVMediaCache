//
//  AVMediaDownload.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

protocol AVMediaDownloadDelegate {
    
    func mediaDownload(_ download: AVMediaDownload, didCompleteError error: Error?)
    func mediaDownload(_ download: AVMediaDownload, didReceiveResponse response: AVMediaDataResponse?)
    func mediaDownload(_ download: AVMediaDownload, didReceiveData data: Data)
}

public typealias UnacceptableContentTypeDisposer = ((URL, String?) -> Bool)

class AVMediaDownload: NSObject {
    
    var timeoutInterval: TimeInterval = 15.0
    
    var whitelistHeaderKeys: [String]?
    
    var additionalHeaders: [String: String]?
    
    var unacceptableContentTypeDisposer: UnacceptableContentTypeDisposer?
    
    // MARK: - Init
    
    static let download = AVMediaDownload()
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    
    // MARK: - Dispatch Request
    
    func downloadWithRequest(_ request: AVMediaDataRequest?, delegate: AVMediaDownloadDelegate?) -> URLSessionTask? {
        guard let request = request else { return nil }
        
        lock()
        var urlRequest = URLRequest(url: request.url)
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.cachePolicy = .reloadIgnoringCacheData
        
        if let header = request.header {
            for (field, value) in header {
                if availableHeaderKeys.contains(field) || whitelistHeaderKeys?.contains(field) ?? false {
                    urlRequest.setValue(value, forHTTPHeaderField: field)
                }
            }
        }
        
        if let additionalHeaders = additionalHeaders {
            for (field, value) in additionalHeaders {
                urlRequest.setValue(value, forHTTPHeaderField: field)
            }
        }
        
        let dataTask = session.dataTask(with: urlRequest)
        requestDictionary[dataTask] = request
        delegateDictionary[dataTask] = delegate
        dataTask.priority = 1.0
        dataTask.resume()
        unlock()
        
        return dataTask
    }
    
    // MARK: - Lazy
    
    private lazy var coreLock: NSRecursiveLock = {
        let lock = NSRecursiveLock()
        lock.name = "\(String(describing: self))" + ".Lock"
        return lock
    }()
    
    private lazy var acceptableContentTypes: [String] = {
        ["video/", "audio/", "application/mp4", "application/octet-stream", "binary/octet-stream"]
    }()
    
    private lazy var availableHeaderKeys: [String] = {
       ["User-Agent","Connection","Accept","Accept-Encoding","Accept-Language","Range"]
    }()
    
    private lazy var session: URLSession = {
        let sessionDelegateQueue = OperationQueue()
        sessionDelegateQueue.qualityOfService = .default
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = timeoutInterval
        sessionConfiguration.requestCachePolicy = .reloadIgnoringCacheData
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: sessionDelegateQueue)
        return session
    }()
    
    private lazy var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    private lazy var errorDictionary = [URLSessionTask: NSError]()
    private lazy var requestDictionary = [URLSessionTask: AVMediaDataRequest]()
    private lazy var delegateDictionary = [URLSessionTask: AVMediaDownloadDelegate]()
}

// MARK: - URLSessionDelegate
extension AVMediaDownload: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock()
        
        guard let dataRequest = requestDictionary[dataTask] else {
            completionHandler(.cancel)
            unlock()
            return
        }
        
        var error: NSError?
        var dataResponse: AVMediaDataResponse?
        if let httpResponse = response as? HTTPURLResponse {
            dataResponse = AVMediaDataResponse(url: dataRequest.url, header: httpResponse.allHeaderFields as? [String: String])
            if httpResponse.statusCode > 400 {
                error = NSError(domain: ErrorDomian,
                                code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                                                        NSURLErrorKey: dataRequest.url as NSURL])
            }
        } else {
            error = NSError(domain: ErrorDomian,
                            code: ErrorCode,
                            userInfo: [NSLocalizedDescriptionKey : "Not a subclass of URLResponse.",
                                                    NSURLErrorKey: dataRequest.url as NSURL])
        }
        
        if let dataResponse = dataResponse, error == nil {
            var valid = false
            if let contentType = dataResponse.contentType, !contentType.isEmpty {
                valid = (acceptableContentTypes.first(where: { contentType.lowercased().contains($0) }) != nil)
            }
            if !valid, let unacceptableContentTypeDisposer = unacceptableContentTypeDisposer {
                valid = unacceptableContentTypeDisposer(dataRequest.url, dataResponse.contentType)
            }
            if !valid {
                error = NSError(domain: ErrorDomian,
                                code: ErrorCode,
                                userInfo: [NSLocalizedDescriptionKey : "Not accept Content-Type.",
                                                        NSURLErrorKey: dataRequest.url as NSURL])
            }
            
            if error == nil {
                if dataResponse.contentLength <= 0 {
                    error = NSError(domain: ErrorDomian,
                                    code: ErrorCode,
                                    userInfo: [NSLocalizedDescriptionKey : "Not valid Content-Length.",
                                                            NSURLErrorKey: dataRequest.url as NSURL])
                }
            }
            if error == nil {
                if !dataRequest.range.isFullRange() && dataResponse.contentLength != dataRequest.range.length() {
                    error = NSError(domain: ErrorDomian,
                                    code: ErrorCode,
                                    userInfo: [NSLocalizedDescriptionKey : "Not valid Content-Range.",
                                                            NSURLErrorKey: dataRequest.url as NSURL])
                }
            }
        }
        
        if let error = error {
            errorDictionary[dataTask] = error
            completionHandler(.cancel)
        } else {
            delegateDictionary[dataTask]?.mediaDownload(self, didReceiveResponse: dataResponse)
            completionHandler(.allow)
        }
        
        unlock()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        lock()
        var downloadError: NSError?
        if let error = error as? NSError {
            downloadError = NSError(domain: ErrorDomian,
                                    code: error.code,
                                    userInfo: error.userInfo)
        }
        if let error = errorDictionary[task] {
            downloadError = error
        }
        
        delegateDictionary[task]?.mediaDownload(self, didCompleteError: downloadError)
        delegateDictionary[task] = nil
        requestDictionary[task] = nil
        errorDictionary[task] = nil
        if delegateDictionary.isEmpty {
            endBackgroundTaskDelay()
        }
        unlock()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock()
        delegateDictionary[dataTask]?.mediaDownload(self, didReceiveData: data)
        unlock()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        lock()
        completionHandler(request)
        unlock()
    }
}

// MARK: - Notification
extension AVMediaDownload {
    
    @objc private func applicationDidEnterBackground(_ notif: Notification) {
        lock()
        if !delegateDictionary.isEmpty {
            beginBackgroundTask()
        }
        unlock()
    }
    
    @objc private func applicationWillEnterForeground(_ notif: Notification) {
        endBackgroundTask()
    }
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.endBackgroundTask()
        })
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func endBackgroundTaskDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.lock()
            if self.delegateDictionary.isEmpty {
                self.endBackgroundTask()
            }
            self.unlock()
        }
    }
}

// MARK: - NSLocking
extension AVMediaDownload: NSLocking {
    
    func lock() {
        coreLock.lock()
    }
    
    func unlock() {
        coreLock.unlock()
    }
}
