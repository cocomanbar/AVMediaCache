//
//  AVRangeUtil.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import Foundation

struct AVRangeUtil {
    
    static func makeRangeStringInHeaderWithRange(_ range: AVRange) -> String {
        
        var value: String = "bytes="
        if range.start != AVRange.NotFound {
            value = value + "\(range.start)"
        }
        value = value + "-"
        if range.end != AVRange.NotFound {
            value = value + "\(range.end)"
        }
        return value
    }
    
    static func fillRangeToRequestHeaders(_ range: AVRange, header: [String: String]?) -> [String: String]? {
        
        let value = makeRangeStringInHeaderWithRange(range)
        var header = header ?? [String: String]()
        header["Range"] = value
        return header
    }
    
    static func fillRangeToRequestHeadersIfNeeded(_ range: AVRange, header: [String: String]?) -> [String: String]? {
        
        guard let header = header, let _ = header["Range"] else { return header }
        return fillRangeToRequestHeaders(range, header: header)
    }
    
    static func fillRangeToResponseHeaders(_ range: AVRange, header: [String: String]?, totalLength: Int64) -> [String: String]? {
        
        guard var header = header else { return header }
        
        header["Content-Length"] = "\(range.length())"
        header["Content-Range"]  = "bytes \(range.start)-\(range.end)/\(totalLength)"
        return header
    }
    
    static func rangeWithSeparateValue(_ value: String) -> AVRange {
        
        var range = AVRange.InvaildRange
        if value.isEmpty {
            return range
        }
        var components: [String] = value.components(separatedBy: ",")
        if components.count != 1 {
            return range
        }

        let value = components.first!
        components = value.components(separatedBy: "-")
        if components.count != 2 {
            return range
        }
        
        let startString = components.first!
        let endString = components.last!
        
        let startValue = Int64(startString) ?? 0
        let endValue = Int64(endString) ?? 0
        
        if !startString.isEmpty && startValue >= 0 && !endString.isEmpty && endValue >= startValue {
            // The second 500 bytes: "500-999"
            range.start = startValue
            range.end = endValue
        } else if !startString.isEmpty && startValue >= 0 {
            // The bytes after 9500 bytes: "9500-"
            range.start = startValue
            range.end = AVRange.NotFound
        } else if !endString.isEmpty && endValue > 0 {
            // The final 500 bytes: "-500"
            range.start = AVRange.NotFound
            range.end = endValue
        }
        return range
    }
    
    static func rangeWithRequestHeaderValue(_ value: String) -> AVRange {
        
        let kety = "bytes="
        if value.hasPrefix(kety) {
            let index: String.Index = value.index(value.startIndex, offsetBy: kety.count)
            let value_ = value[index...]
            return rangeWithSeparateValue(String(value_))
        }
        return AVRange.InvaildRange
    }
    
    static func rangeWithResponseHeaderValue(_ value: String, totalLength: inout Int64) -> AVRange {
        
        let kety = "bytes "
        if value.hasPrefix(kety) {
            let value_ = value.replacingOccurrences(of: kety, with: "")
            guard let range: Range<String.Index> = value_.range(of: "/") else { return AVRange.InvaildRange }
            let rangeString = value_[..<range.lowerBound]
            let totalLengthString = value_[range.upperBound...]
            if let totalLengthStringValue = Int64(totalLengthString) {
                totalLength = totalLengthStringValue
            }
            return rangeWithSeparateValue(String(rangeString))
        }
        return AVRange.InvaildRange
    }
    
    static func rangeWithEnsureLength(_ range: AVRange, ensureLength: Int64) -> AVRange {
        
        if range.end == AVRange.NotFound && ensureLength > 0 {
            return AVRange(start: range.start, end: ensureLength - 1)
        }
        return range
    }
}
