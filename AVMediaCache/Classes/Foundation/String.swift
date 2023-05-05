//
//  String.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/21.
//

import Foundation
import CommonCrypto

extension String: AVMediaCacheCompatibleValue {}

extension AVMediaCacheWrapper where Base == String {
    
    var md5: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    var encodeURL: String {
        guard let encode = base.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return base }
        return encode
    }
    
    var decodeURL: String {
        guard let decode = base.removingPercentEncoding else { return base }
        return decode
    }
    
    var base64Encode: String? {
        guard let data = base.data(using: .utf8) else { return nil }
        return data.base64EncodedString()
    }
    
    var base64Decode: String? {
        guard let data = Data.init(base64Encoded: base) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
