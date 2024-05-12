//
//  File.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

internal extension URL {
    func deduplicatedURL(isDirectory: Bool) -> URL {
        var index = 1
        while index < 1_000 {
            index += 1
            let newURL = deduplicatedURL(index: index, isDirectory: isDirectory)
            let exists = try! CoordinatedFileManager().exists(at: newURL)
            if !exists.exists {
                return newURL
            }
        }
        fatalError("Couldn't generate deduplicated URL for \(self)")
    }
    
    private func deduplicatedURL(index: Int, isDirectory: Bool) -> URL {
        let ext = self.pathExtension
        let filename = self.deletingPathExtension().lastPathComponent
        let updatedFilename = "\(filename) \(index).\(ext)"
        return deletingLastPathComponent().appendingPathComponent(updatedFilename, isDirectory: isDirectory)
    }
}
