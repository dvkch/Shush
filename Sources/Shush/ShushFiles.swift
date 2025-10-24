//
//  ShushFiles.swift
//  Shush
//
//  Created by syan on 23/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class ShushFiles<P: Persistable, V: Comparable>: NSObject {
    
    // MARK: Init
    public enum Source {
        case url(URL)
        @available(tvOS, unavailable)
        case documents(subdirectory: String?)
        case ubiquityContainer(name: String)
        
        public var available: Bool {
            switch self {
            case .url(let url):
                return FileManager.default.fileExists(atPath: url.standardizedFileURL.path)
            case .documents:
                return true
            case .ubiquityContainer(let name):
                return FileManager.default.url(forUbiquityContainerIdentifier: name) != nil
            }
        }
        
        public var url: URL {
            switch self {
            case .url(let url): return url
            case .documents(let subdirectory):
                var url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                if let subdirectory {
                    url = url.appendingPathComponent(subdirectory, isDirectory: true)
                }
                return url
            case .ubiquityContainer(let name):
                guard let url = FileManager.default.url(forUbiquityContainerIdentifier: name) else {
                    fatalError("Unknown container \(name)")
                }
                return url
            }
        }
    }

    public init(_ source: Source, sortedBy: KeyPath<ShushFile<P>, V>, order: Order, notification: Notification.Name? = nil, refreshInterval: TimeInterval = 5) {
        self.source = source
        self.baseURL = source.url.standardizedFileURL
        self.keyPath = sortedBy
        self.order = order
        self.notification = notification
        self.monitor = .init(baseURL: baseURL, fileExtension: P.fileExtension, interval: refreshInterval)
        super.init()

        if (try? CoordinatedFileManager().exists(at: baseURL).exists) != true {
            try? CoordinatedFileManager().createDirectory(at: baseURL, withIntermediateDirectories: true)
        }

        monitor.delegate = self
        contentChanged(changes: [.reload], notifiy: false)
    }

    // MARK: Configuration
    public let source: Source
    private let baseURL: URL
    private let keyPath: KeyPath<ShushFile<P>, V>
    private let order: Order
    private let notification: Notification.Name?
    private let monitor: UbiquityContainerMonitor

    // MARK: Types
    public enum Order {
        case asc, desc
    }
    
    private enum Change {
        case reload
        case insert([StandardizedURL])
        case insertLoaded([(StandardizedURL, P.Partial)])
        case delete([StandardizedURL])
        
        var isNoop: Bool {
            switch self {
            case .reload: return false
            case .insert(let items): return items.isEmpty
            case .insertLoaded(let items): return items.isEmpty
            case .delete(let items): return items.isEmpty
            }
        }
    }

    // MARK: Content
    private var unsortedFiles: [StandardizedURL: P.Partial] = [:] {
        didSet {
            files = unsortedFiles
                .map { .init(url: $0.url, partial: $1) }
                .sorted(by: keyPath, ascending: order == .asc)
        }
    }
    public private(set) var files: [ShushFile<P>] = []
    
    private func contentChanged(changes: [Change], notifiy: Bool = true) {
        let actualChanges = changes.filter { !$0.isNoop }
        for change in actualChanges {
            switch change {
            case .reload:
                do {
                    unsortedFiles = try CoordinatedFileManager()
                        .contents(of: baseURL, properties: [URLResourceKey.isRegularFileKey], options: [])
                        .filter { (try? $0.resourceValues(forKeys: Set<URLResourceKey>([.isRegularFileKey])).isRegularFile) == true }
                        .filter { $0.pathExtension == P.fileExtension }
                        .map { StandardizedURL(url: $0) }
                        .compactMap { self.partialRead(at: $0) }
                        .reduce(into: [:], { $0[$1.0] = $1.1 })
                }
                catch {
                    log(.error, "Couldn't list files at \(baseURL): \(error)")
                }
                
            case .insert(let items):
                let preloaded = items.compactMap { self.partialRead(at: $0) }
                return self.contentChanged(changes: [.insertLoaded(preloaded)], notifiy: notifiy)
                
            case .insertLoaded(let items):
                var unsortedFiles = self.unsortedFiles
                items.forEach { (url, file) in
                    unsortedFiles[url] = file
                }
                self.unsortedFiles = unsortedFiles

            case .delete(let items):
                var unsortedFiles = self.unsortedFiles
                items.forEach { (url) in
                    unsortedFiles[url] = nil
                }
                self.unsortedFiles = unsortedFiles
            }
        }
        
        if actualChanges.isNotEmpty && notifiy {
            postNotification()
        }
    }
    
    private func partialRead(at url: StandardizedURL) -> (StandardizedURL, P.Partial)? {
        do {
            let data = try CoordinatedFileManager().read(fileAt: url.url)
            return (url, try P.decodePersistedPartially(data))
        }
        catch {
            log(.warn, "Couldn't decode metadata at \(url): \(error)")
            return nil
        }
    }

    // MARK: Public methods
    public func read(_ box: ShushFile<P>) throws -> P {
        let data = try CoordinatedFileManager().read(fileAt: box.id.url)
        return try P.decodePersisted(data)
    }

    @discardableResult
    public func insert(_ elements: [(P, filename: String)]) -> [ShushFile<P>] {
        let elementsWithURL = elements.map { (element, filename) in
            let url = baseURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension(P.fileExtension)
            return (element, StandardizedURL(url: url))
        }

        for (element, url) in elementsWithURL {
            do {
                let data = try P.encodePersisted(element)
                try CoordinatedFileManager().write(data, to: url.url)
            }
            catch {
                log(.warn, "Couldn't save file at \(url): \(error)")
            }
        }
        contentChanged(changes: [.insertLoaded(elementsWithURL.map { ($0.1, $0.0.partialRepresentation) })])
        return elementsWithURL.map { .init(url: $0.1.url, partial: $0.0.partialRepresentation) }
    }
    
    @discardableResult
    public func insert(_ element: P, filename: String) -> ShushFile<P> {
        insert([(element, filename)]).first!
    }
    
    @discardableResult
    public func insert(_ elements: [P]) -> [ShushFile<P>] where P: PersistableIdentifiable {
        insert(elements.map { ($0, P.suggestedFilename(for: $0)) })
    }
    
    @discardableResult
    public func insert(_ element: P) -> ShushFile<P> where P: PersistableIdentifiable {
        insert([element]).first!
    }
    
    public func remove(_ elements: [ShushFile<P>]) {
        elements.forEach { element in
            try? CoordinatedFileManager().removeItem(at: element.id.url)
        }
        contentChanged(changes: [.delete(elements.map { StandardizedURL(url: $0.id.url) })])
    }
    
    public func remove(_ element: ShushFile<P>) {
        remove([element])
    }

    public func clear(includingUnknownFiles: Bool) {
        if includingUnknownFiles {
            try? CoordinatedFileManager()
                .contents(of: baseURL, properties: [URLResourceKey.isRegularFileKey], options: [])
                .forEach { try? CoordinatedFileManager().removeItem(at: $0) }
        }
        remove(files)
        contentChanged(changes: [.reload])
    }
    
    // MARK: Conflicts resolution
    public func resolveConflicts(for file: ShushFile<P>, keeping keptVersions: [NSFileVersion]) throws {
        let current = NSFileVersion.currentVersionOfItem(at: file.id.url)!

        guard keptVersions.isNotEmpty else {
            remove(file)
            return
        }

        //  https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/DocumentBasedAppPGiOS/ResolveVersionConflicts/ResolveVersionConflicts.html

        var updatedURLs = Set<URL>()
        
        for (i, version) in keptVersions.enumerated() {
            // we cannot call NSFileVersion.replaceItem(at: URL) on the current version, which
            // means if it is kept, it has to stay the current version
            if version == current {
                version.isResolved = true
                updatedURLs.insert(file.id.url)
            }
            // we're not keeping the current version, let's replace it by the first kept version
            else if i == 0, !keptVersions.contains(current) {
                try renameVersion(version, to: file.id.url)
                updatedURLs.insert(file.id.url)
            }
            else {
                let isDirectory = try! CoordinatedFileManager().exists(at: file.id.url).isDirectory
                let deduplicatedURL = file.id.url.deduplicatedURL(isDirectory: isDirectory)
                try renameVersion(version, to: deduplicatedURL)
                updatedURLs.insert(deduplicatedURL)
            }
        }

        try CoordinatedFileManager().coordinate(.writingIntent(with: file.id.url)) { updatedURL in
            try NSFileVersion.removeOtherVersionsOfItem(at: updatedURL)
            NSFileVersion.currentVersionOfItem(at: updatedURL)?.isResolved = true
            NSFileVersion.unresolvedConflictVersionsOfItem(at: updatedURL)?.forEach { $0.isResolved = true }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.contentChanged(changes: [.insert(updatedURLs.map(StandardizedURL.init))])
        }
    }
    
    private func renameVersion(_ version: NSFileVersion, to url: URL) throws {
        let destinationIntent = NSFileAccessIntent.writingIntent(with: url, options: .forReplacing)
        let sourceIntent = NSFileAccessIntent.writingIntent(with: version.url, options: .forMoving)
        
        try CoordinatedFileManager().coordinate([destinationIntent, sourceIntent]) { _ in
            try version.replaceItem(at: destinationIntent.url, options: .byMoving)
            version.isResolved = true
        }
    }

    // MARK: Sync
    private var disabledNotificationsURLs: Set<StandardizedURL> = []
    public func toggleNotifications(for file: ShushFile<P>, enabled: Bool) {
        if enabled {
            disabledNotificationsURLs.remove(.init(url: file.id.url))
        }
        else {
            disabledNotificationsURLs.insert(.init(url: file.id.url))
        }
    }

    private func postNotification() {
        guard let notification else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notification, object: nil)
        }
    }
}

extension ShushFiles: UbiquityContainerMonitorDelegate {
    func ubiquityContainerMonitor(_ monitor: UbiquityContainerMonitor, inserted: [URL], updated: [URL], removed: [URL]) {
        let insertions  = inserted.map { StandardizedURL(url: $0) }.filter { !disabledNotificationsURLs.contains($0) }
        let updates     = updated.map  { StandardizedURL(url: $0) }.filter { !disabledNotificationsURLs.contains($0) }
        let removals    = removed.map  { StandardizedURL(url: $0) }.filter { !disabledNotificationsURLs.contains($0) }
        let removedURLs = (removals + updates)
        let insertedURLs = (updates + insertions)
        
        guard insertions.count + updates.count + removals.count > 0 else { return }
        log(.info, "Received changes: \(insertions.count) insertions, \(updates.count) updates, \(removals.count) removals")
        contentChanged(changes: [.delete(removedURLs), .insert(insertedURLs)], notifiy: true)
    }
}

extension ShushFiles: Loggable {
    var logTag: String {
        return "FileArray(\(baseURL))"
    }
}
