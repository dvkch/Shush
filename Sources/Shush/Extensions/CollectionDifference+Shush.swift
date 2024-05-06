//
//  CollectionDifference+Shush.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

internal extension CollectionDifference.Change {
    var element: ChangeElement {
        switch self {
        case let .insert(_, element, _), let .remove(_, element, _):
            return element
        }
    }
}

internal extension CollectionDifference where ChangeElement: Identifiable {
    var changes: (inserted: [ChangeElement], updated: [ChangeElement], removed: [ChangeElement]) {
        var inserted = self.insertions.map(\.element)
        var removed = self.removals.map(\.element)
        let updatedIDs = Set(inserted.map(\.id)).intersection(removed.map(\.id))
        let updated = updatedIDs.map { id in inserted.first(where: { $0.id == id })! }
        inserted.removeAll(where: { updatedIDs.contains($0.id) })
        removed.removeAll(where: { updatedIDs.contains($0.id) })
        return (inserted, updated, removed)
    }
}
