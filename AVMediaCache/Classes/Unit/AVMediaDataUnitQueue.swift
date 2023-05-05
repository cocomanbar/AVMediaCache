//
//  AVMediaDataUnitQueue.swift
//  AVMediaCache
//
//  Created by tanxl on 2023/4/23.
//

import UIKit

class AVMediaDataUnitQueue: NSObject {
    
    private var path: String
    private var units: [AVMediaDataUnit] = [AVMediaDataUnit]()
    
    // MARK: - Init
    
    init(_ path: String) {
        self.path = path
        super.init()
                
        do {
            let decoder = JSONDecoder()
            let url = NSURL(fileURLWithPath: path) as URL
            let data = try Data.init(contentsOf: url)
            units = try decoder.decode([AVMediaDataUnit].self, from: data)
        } catch {

        }
        
        if !units.isEmpty {
            var removal = [AVMediaDataUnit]()
            for unit in units {
                if let _ = unit.error {
                    unit.deleteFiles()
                    removal.append(unit)
                }
            }
            if !removal.isEmpty {
                units = units.filter({ !removal.contains($0) })
            }
        }
    }
    
    
    func allUnits() -> [AVMediaDataUnit] {
        units
    }
    
    func unitWithKey(_ key: String?) -> AVMediaDataUnit? {
        guard let key = key, !key.isEmpty else { return nil }
        let unit: AVMediaDataUnit? = units.first(where: { unit in
            unit.key == key
        })
        return unit
    }
    
    func putUnit(_ unit: AVMediaDataUnit?) {
        guard let unit = unit, !units.contains(unit) else { return }
        units.append(unit)
    }
    
    func popUnit(_ unit: AVMediaDataUnit?) {
        guard let unit = unit, units.contains(unit) else { return }
        units.removeAll { $0.key == unit.key }
    }
    
    func archive() {
        do {
            let encoder = JSONEncoder()
            let encoded: Data = try encoder.encode(units)
            (encoded as NSData).write(toFile: path, atomically: true)
        } catch {
            
        }
    }
}
