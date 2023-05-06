//
//  AVMediaPathUtil.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

struct AVMediaPathUtil {
    
    private static let root: String = "AVMediaCache"
    
    static func basePath() -> String {
        NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last ?? ""
    }
    
    static func rootDirectory() -> String {
        createDirectoryAtPath(root)
        return root
    }
    
    static func archivePath() -> String {
        let path = (rootDirectory() as NSString).appendingPathComponent("\(root).archive")
        return converToAbsoultePath(path)
    }
}

// MARK: - Conver
extension AVMediaPathUtil {
    
    static func converToAbsoultePath(_ path: String) -> String {
        var path: String = path
        if isRelativePath(path) {
            path = (basePath() as NSString).appendingPathComponent(path)
        }
        return path
    }
    
    static func converToRelativePath(_ path: String) -> String {
        var path: String = path
        if isAbsolutePath(path) {
            path = (path as NSString).replacingOccurrences(of: basePath(), with: "")
        }
        return path
    }
    
}

// MARK: - File Size
extension AVMediaPathUtil {
    
    static func sizeAtPath(_ path: String?) -> Int64 {
        guard let path = path, !path.isEmpty else { return 0 }
        let absoultePath = converToAbsoultePath(path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: absoultePath) else { return 0 }
        if let size = attributes[.size] as? Int64 {
            return size
        }
        return 0
    }
}

// MARK: - Operation
extension AVMediaPathUtil {
    
    @discardableResult
    static func deleteFileAtPath(_ path: String?) -> Error? {
        var err: Error?
        guard let path = path, !path.isEmpty else { return err }
        
        let absoultePath = converToAbsoultePath(path)
        var isDirectory = ObjCBool(false)
        let result = FileManager.default.fileExists(atPath: absoultePath, isDirectory: &isDirectory)
        if result && !isDirectory.boolValue {
            do {
                try FileManager.default.removeItem(atPath: absoultePath)
            } catch {
                err = error
            }
        }
        return err
    }
    
    @discardableResult
    static func deleteDirectoryAtPath(_ path: String?) -> Error? {
        var err: Error?
        guard let path = path, !path.isEmpty else { return err }
        
        let absoultePath = converToAbsoultePath(path)
        var isDirectory = ObjCBool(false)
        let result = FileManager.default.fileExists(atPath: absoultePath, isDirectory: &isDirectory)
        if result && isDirectory.boolValue {
            do {
                try FileManager.default.removeItem(atPath: absoultePath)
            } catch {
                err = error
            }
        }
        return err
    }
    
    static func createFileAtPath(_ path: String?) {
        guard var path = path, !path.isEmpty else { return }
        path = converToAbsoultePath(path)
        var isDirectory = ObjCBool(false)
        let isExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if !isExists || isDirectory.boolValue {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
    }
    
    static func directoryPathWithURL(_ url: URL) -> String {
        let key = AVMediaURLUtil.shared.keyWithURL(url: url)
        let path = (rootDirectory() as NSString).appendingPathComponent(key)
        createDirectoryAtPath(path)
        return converToAbsoultePath(path)
    }
    
    static func completeFilePathWithURL(_ url: URL?) -> String? {
        guard let url = url else { return nil }
        let key = AVMediaURLUtil.shared.keyWithURL(url: url)
        guard let fileName = (key as NSString).appendingPathExtension(url.pathExtension) else {
            return nil
        }
        let directoryPath = directoryPathWithURL(url)
        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)
        return converToAbsoultePath(filePath)
    }
    
    static func filePathWithURL(_ url: URL, offset: Int64) -> String {
        let baseFileName = AVMediaURLUtil.shared.keyWithURL(url: url)
        let directoryPath = directoryPathWithURL(url)
        var number: Int = 0
        var filePath: String?
        while filePath == nil {
            let fileName = baseFileName + "_" + "\(offset)" + "_" + "\(number)"
            let currentFilePath = (directoryPath as NSString).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: currentFilePath) == false {
                FileManager.default.createFile(atPath: currentFilePath, contents: nil)
                filePath = currentFilePath
            }
            number += 1
        }
        guard let filePath = filePath else { return "" }
        return converToAbsoultePath(filePath)
    }
}

// MARK: - Private
extension AVMediaPathUtil {
    
    private static func isAbsolutePath(_ path: String) -> Bool {
        (path as NSString).hasPrefix(basePath())
    }
    
    private static func isRelativePath(_ path: String) -> Bool {
        isAbsolutePath(path) == false
    }
    
    private static func createDirectoryAtPath(_ path: String) {
        if path.isEmpty {
            return
        }
        let path: String = converToAbsoultePath(path)
        var isDirectory = ObjCBool(false)
        let isExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if !isExists || !isDirectory.boolValue {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
}
