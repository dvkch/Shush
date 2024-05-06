//
//  ShushFile.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

public class ShushFile<T: Persistable>: Identifiable {
    internal init(url: URL, partial: T.Partial) {
        self.id = .init(url: url)
        self.filename = url.lastPathComponent
        self.partial = partial
    }
    
    public let id: ShushFileID
    public let filename: String
    public let partial: T.Partial
}

public struct ShushFileID: Hashable {
    internal init(url: URL) {
        self.url = url
    }
    
    internal let url: URL
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

extension ShushFile: Hashable where T.Partial: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(partial)
    }
}

extension ShushFile: Equatable where T.Partial: Equatable {
    public static func == (lhs: ShushFile<T>, rhs: ShushFile<T>) -> Bool {
        return lhs.id == rhs.id && lhs.partial == rhs.partial
    }
}
