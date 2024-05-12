//
//  NSMetadataQuery+Shush.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

internal extension NSMetadataQuery {
    var items: [NSMetadataItem.Item] {
        disableUpdates()
        defer { enableUpdates() }

        return (results as? [NSMetadataItem] ?? []).map(\.item)
    }
}
