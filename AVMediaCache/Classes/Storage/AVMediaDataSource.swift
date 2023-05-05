//
//  AVMediaDataSource.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/26.
//

import Foundation

protocol AVMediaDataSource {
    
    var hashValue: Int { get }
    
    var error: Error? { get }
    
    var isPrepared: Bool { get }
    var isFinished: Bool { get }
    var isClosed: Bool { get }
    
    var range: AVRange { get }
    var readedLength: Int64 { get }
    
    func prepare()
    func close()
    
    func readDataOfLength(_ length: Int64?) -> Data?
}
