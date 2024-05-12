//
//  ShushFile.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

public struct ShushFile<T: Persistable>: Identifiable, Hashable {
    internal init(url: URL, partial: T.Partial) {
        self.id = .init(url: url)
        self.filename = url.lastPathComponent
        self.partial = partial
        self.currentVersion = NSFileVersion.currentVersionOfItem(at: url)
        self.conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
    }
    
    public let id: ShushFileID
    public let filename: String
    public let partial: T.Partial
    public let currentVersion: NSFileVersion?
    public let conflicts: [NSFileVersion]
    
    public var hasConflicts: Bool {
        return conflicts.isNotEmpty
    }
}

public struct ShushFileID: Hashable {
    internal init(url: URL) {
        self.url = url
    }
    
    internal let url: URL
}
