//
//  CoordinatedFileManager.swift
//  Shush
//
//  Created by syan on 08/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

// https://github.com/drewmccormack/SwiftCloudDrive/blob/main/Sources/SwiftCloudDrive/FileManager%2BCoordination.swift
internal class CoordinatedFileManager {
    
    // MARK: Init
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: Properties
    private let fileManager: FileManager
    
    // MARK: Methods
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try coordinate(.writingIntent(with: url, options: .forMerging)) {
            try fileManager.createDirectory(at: $0, withIntermediateDirectories: withIntermediateDirectories)
        }
    }

    func exists(at url: URL) throws -> (exists: Bool, isDirectory: Bool) {
        var isDir: ObjCBool = false
        var exists: Bool = false
        try coordinate(.readingIntent(with: url)) {
            exists = fileManager.fileExists(atPath: $0.path, isDirectory: &isDir)
        }
        return (exists, isDir.boolValue)
    }

    func removeItem(at url: URL) throws {
        try coordinate(.writingIntent(with: url, options: .forDeleting)) {
            try fileManager.removeItem(at: $0)
        }
    }
    
    func contents(of url: URL, properties: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        var contents: [URL] = []
        try coordinate(.readingIntent(with: url)) {
            contents = try fileManager.contentsOfDirectory(at: $0, includingPropertiesForKeys: properties, options: options)
        }
        return contents
    }
    
    func read(fileAt url: URL) throws -> Data {
        var data: Data = .init()
        try coordinate(.readingIntent(with: url)) {
            data = try Data(contentsOf: $0, options: [])
        }
        return data
    }
    
    func write(_ data: Data, to url: URL) throws {
        try coordinate(.writingIntent(with: url)) {
            try data.write(to: $0, options: .atomic)
        }
    }
}

internal extension CoordinatedFileManager {
    private func execute(_ block: (URL) throws -> Void, onSecurityScopedResource url: URL) throws {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        try block(url)
    }
    
    private class State {
        init() {
            self.isReady = false
            self.isFinished = false
        }
        
        var isReady: Bool
        var isFinished: Bool
    }
    
    // Extremely cursed, but it works...
    // The idea is to be able to run the block synchronously on the calling thread, which is possible
    // with other variants of NSFileCoordinator.coordinate... methods, but not the more generic one here
    func coordinate(_ intent: NSFileAccessIntent, block: (URL) throws -> Void) throws {
        var coordinatorError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.underlyingQueue = .global(qos: .userInitiated)
        
        let state = State()
        coordinator.coordinate(with: [intent], queue: queue) { coordError in
            coordinatorError = coordError
            state.isReady = true
            while !state.isFinished { usleep(1000) }
        }
        
        while !state.isReady { usleep(1000) }
        guard coordinatorError == nil else { throw coordinatorError! }
        
        try execute(block, onSecurityScopedResource: intent.url)
        state.isFinished = true
    }
}
