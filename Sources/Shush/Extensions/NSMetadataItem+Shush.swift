//
//  NSMetadataItem+Shush.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

internal extension NSMetadataItem {
    struct Item: Equatable, Identifiable, Hashable {
        let url: URL
        let size: Int64
        let date: Date
        let availability: Availability
        let downloading: Bool
        let hasConflicts: Bool
        
        var id: URL {
            return url
        }

        enum Availability: CaseIterable {
            case notAvailable
            case outdated
            case upToDate
            
            var equivalentAttributeValue: String {
                switch self {
                case .notAvailable: return NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
                case .outdated: return NSMetadataUbiquitousItemDownloadingStatusDownloaded
                case .upToDate: return NSMetadataUbiquitousItemDownloadingStatusCurrent
                }
            }
            
            init(status: String) {
                self = Self.allCases.first(where: { $0.equivalentAttributeValue == status }) ?? .notAvailable
            }
        }
    }
    
    private subscript<T>(key: String, as type: T.Type) -> T {
        return value(forAttribute: key) as! T
    }

    var item: Item {
        return .init(
            url: self[NSMetadataItemURLKey, as: URL.self],
            size: self[NSMetadataItemFSSizeKey, as: Int64.self],
            date: self[NSMetadataItemFSContentChangeDateKey, as: Date?.self] ?? self[NSMetadataItemFSCreationDateKey, as: Date.self],
            availability: .init(status: self[NSMetadataUbiquitousItemDownloadingStatusKey, as: String.self]),
            downloading: self[NSMetadataUbiquitousItemIsDownloadingKey, as: Bool.self],
            hasConflicts: self[NSMetadataUbiquitousItemHasUnresolvedConflictsKey, as: Bool.self]
        )
    }
}
