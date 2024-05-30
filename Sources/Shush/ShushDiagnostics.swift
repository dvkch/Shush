//
//  ShushDiagnostics.swift
//
//
//  Created by syan on 30/05/2024.
//

import Foundation

public enum ShushDiagnostics {
    // MARK: UserDefaults
    // https://developer.apple.com/documentation/foundation/userdefaults/1617187-sizelimitexceedednotification
    case userDefaultsReachedTvOSSoftLimit(size: Int)
    case userDefaultsReachedTvOSHardLimit(size: Int)

    // MARK: NSUbiquitousKeyValueStore
    // https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore
    case ubiquitousHasTooManyKeys(count: Int)
    case ubiquitousLimitReachedForItems(keys: [String])
    case ubiquitousLimitReached(totalSize: Int)
    
    // MARK: Evaluate current issues
    public static func verify(_ userDefaults: UserDefaults? = .standard, _ ubiquitous: NSUbiquitousKeyValueStore? = .default) -> [ShushDiagnostics] {
        var diagnostics = [ShushDiagnostics]()
        
        let halfMB = 512 * 1024
        let oneMB = 1024 * 1024

        if let ud = userDefaults {
            let userDefaultsKeys = ud.dictionaryRepresentation().keys
            let userDefaultsSize = userDefaultsKeys.map { ud.data(forKey: $0)?.count ?? 0 }.reduce(0, +)
            if userDefaultsSize >= oneMB {
                diagnostics.append(.userDefaultsReachedTvOSHardLimit(size: userDefaultsSize))
            }
            if userDefaultsSize >= halfMB {
                diagnostics.append(.userDefaultsReachedTvOSSoftLimit(size: userDefaultsSize))
            }
        }
        
        if let ub = ubiquitous {
            let ubiquitousKeys = ub.dictionaryRepresentation.keys
            let ubiquitousSizes = ubiquitousKeys.map { ($0, ub.data(forKey: $0)?.count ?? 0) }
            let ubiquitousHeavyKeys = ubiquitousSizes.filter { $0.1 >= oneMB }.map(\.0)
            let ubiquitousTotalSize = ubiquitousSizes.map(\.1).reduce(0, +)
            
            if ubiquitousKeys.count >= 1024 {
                diagnostics.append(.ubiquitousHasTooManyKeys(count: ubiquitousKeys.count))
            }
            if ubiquitousHeavyKeys.isNotEmpty {
                diagnostics.append(.ubiquitousLimitReachedForItems(keys: ubiquitousHeavyKeys))
            }
            if ubiquitousTotalSize >= oneMB {
                diagnostics.append(.ubiquitousLimitReached(totalSize: ubiquitousTotalSize))
            }
        }
        
        return diagnostics
    }
}
