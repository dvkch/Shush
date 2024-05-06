//
//  Persistable.swift
//  Shush
//
//  Created by syan on 05/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

public protocol Persistable {
    associatedtype Partial: PersistablePartial
    
    var partialRepresentation: Partial { get }
    
    static func decodePersisted(_ data: Data) throws -> Self
    static func encodePersisted(_ data: Self) throws -> Data
    static func decodePersistedPartially(_ data: Data) throws -> Partial
    
    static var fileExtension: String { get }
}

public protocol PersistablePartial {}
public protocol PersistableIdentifiable {
    static func suggestedFilename(for persistable: Self) -> String
}
