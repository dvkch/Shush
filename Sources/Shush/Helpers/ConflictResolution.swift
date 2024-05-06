//
//  ConflictResolution.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

public enum ConflictResolution {
    case ignore
    case deleteOthers
    case renameOthers
    case keep(version: NSFileVersion)
}
