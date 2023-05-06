//
//  AVMediaDataResponse.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

class AVMediaDataResponse: NSObject {
    
    private(set) var url: URL
    private(set) var header: [String: String]?
    private(set) var contentType: String?
    private(set) var contentLength: Int64 = 0
    private(set) var totalLength: Int64 = 0
    private(set) var contentRange: AVRange?
    private(set) var contentRangeString: String?
    
    // MARK: - Init
    
    init(url: URL, header: [String: String]?) {
        self.url = url
        self.header = header
        super.init()
        
        commonInit()
    }
    
    deinit {
        
    }
    
    // MARK: - commonInit
    
    private func commonInit() {
        
        guard let header = header else { return }
        
        // contentType
        self.contentType = header.av.headerValueWithKey("Content-Type")
        
        // contentLength
        if let contentLength = header.av.headerValueWithKey("Content-Length"), let contentLengthValue = Int64(contentLength) {
            self.contentLength = contentLengthValue
        }
        
        // contentRangeString
        if let contentRangeString = header.av.headerValueWithKey("Content-Range") {
            self.contentRange = AVRangeUtil.rangeWithResponseHeaderValue(contentRangeString, totalLength: &self.totalLength)
            self.contentRangeString = contentRangeString
        }
        
    }
}
