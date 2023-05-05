//
//  AVRange.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import Foundation

struct AVRange {
    
    var start: Int64
    var end: Int64
    
    init(start: Int64, end: Int64) {
        self.start = start
        self.end = end
    }
    
    static let NotFound = Int64.max
    static let ZeroRange = AVRange(start: 0, end: 0)
    static let FullRange = AVRange(start: 0, end: NotFound)
    static let InvaildRange = AVRange(start: NotFound, end: NotFound)
}

extension AVRange: CustomStringConvertible {
    
    var description: String {
        "Range: {\(start), \(end)}"
    }
}

extension AVRange: Equatable, Hashable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.start == rhs.start && lhs.end == rhs.end
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(end)
    }
}

extension AVRange {
    
    func isFullRange() -> Bool {
        self == AVRange.FullRange
    }
    
    func isVaildRange(_ range: AVRange) -> Bool {
        !isInvaildRange(range)
    }
    
    func isInvaildRange(_ range: AVRange) -> Bool {
        self == AVRange.InvaildRange
    }
    
    func length() -> Int64 {
        if start == AVRange.NotFound || end == AVRange.NotFound {
            return AVRange.NotFound
        }
        return end - start + 1
    }
}
