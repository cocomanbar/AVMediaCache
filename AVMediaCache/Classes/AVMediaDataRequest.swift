//
//  AVMediaDataRequest.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

class AVMediaDataRequest: NSObject {
    
    private(set) var url: URL
    private(set) var range: AVRange = AVRange.FullRange
    
    private(set) var header: [String: String]?
    
    // MARK: - Init
    
    init(url: URL, header: [String: String]?) {
        self.url = url
        self.header = header
        super.init()
        
        commonInit()
    }
    
    func newRequestWithRange(_ range: AVRange) -> AVMediaDataRequest {

        let headers = AVRangeUtil.fillRangeToRequestHeaders(range, header: header)
        let dataRequest = AVMediaDataRequest(url: url, header: headers)
        return dataRequest
    }
    
    func newRequestWithTotalLength(_ totalLength: Int64) -> AVMediaDataRequest {
        
        let rangeEnsure = AVRangeUtil.rangeWithEnsureLength(range, ensureLength: totalLength)
        return newRequestWithRange(rangeEnsure)
    }
    
    // MARK: - commonInit
    
    private func commonInit() {
        
        var range: AVRange = AVRange.FullRange
        if let header = header, let rangeString = header["Range"] {
            range = AVRangeUtil.rangeWithRequestHeaderValue(rangeString)
        }
        self.range = range
    }
}
