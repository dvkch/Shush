//
//  ShushFiles.swift
//  Shush
//
//  Created by syan on 23/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

public protocol ShushFilesDelegate: NSObjectProtocol {
    func shushFilesNeedsConflictResolution(for url: URL, versions: [NSFileVersion], completion: @escaping (ConflictResolution) -> ())
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class ShushFiles<P: Persistable, V: Comparable>: NSObject {
    
    // MARK: Init
    public convenience init(ubiquityContainer: String, sortedBy: KeyPath<ShushFile<P>, V>, order: Order, notification: Notification.Name? = nil) {
        guard let cloudURL = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainer) else {
            fatalError("Unknown container \(ubiquityContainer)")
        }
        let baseURL = cloudURL.appendingPathComponent("Documents", isDirectory: true)
        self.init(baseURL: baseURL, sortedBy: sortedBy, order: order, notification: notification)
    }

    public init(baseURL: URL, sortedBy: KeyPath<ShushFile<P>, V>, order: Order, notification: Notification.Name? = nil) {
        self.baseURL = baseURL.standardizedFileURL
        self.keyPath = sortedBy
        self.order = order
        self.notification = notification
        self.monitor = .init(baseURL: baseURL, fileExtension: P.fileExtension)
        super.init()

        if (try? CoordinatedFileManager().exists(at: baseURL).exists) != true {
            try? CoordinatedFileManager().createDirectory(at: baseURL, withIntermediateDirectories: true)
        }

        monitor.delegate = self
        contentChanged(change: .reload, notifiy: false)
    }

    // MARK: Configuration
    public weak var delegate: ShushFilesDelegate?
    private let monitor: UbiquityContainerMonitor
    private let baseURL: URL
    private let keyPath: KeyPath<ShushFile<P>, V>
    private let order: Order
    private let notification: Notification.Name?
    
    // MARK: Types
    public enum Order {
        case asc, desc
    }
    
    private enum Change {
        case reload
        case insert([(StandardizedURL, P.Partial)])
        case delete([StandardizedURL])
    }
    
    private struct StandardizedURL: Hashable {
        let url: URL
        init(url: URL) {
            self.url = url.standardizedFileURL
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
        }
        static func == (lhs: StandardizedURL, rhs: StandardizedURL) -> Bool {
            return lhs.url == rhs.url
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
    
    private func contentChanged(change: Change, notifiy: Bool = true) {
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
        
        if notifiy {
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
        contentChanged(change: .insert(elementsWithURL.map { ($0.1, $0.0.partialRepresentation) }))
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
        contentChanged(change: .delete(elements.map { StandardizedURL(url: $0.id.url) }))
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
        contentChanged(change: .reload)
    }

    // MARK: Sync
    private func postNotification() {
        guard let notification else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notification, object: nil)
        }
    }
}

extension ShushFiles: UbiquityContainerMonitorDelegate {
    func ubiquityContainerMonitor(_ monitor: UbiquityContainerMonitor, inserted: [URL], updated: [URL], removed: [URL]) {
        let removedURLs = (removed + updated).map { StandardizedURL(url: $0) }
        let insertedURLs = (updated + inserted).map { StandardizedURL(url: $0) }
        let insertedContents = insertedURLs.compactMap { partialRead(at: $0) }

        contentChanged(change: .delete(removedURLs), notifiy: false)
        contentChanged(change: .insert(insertedContents), notifiy: true)
    }
    
    func ubiquityContainerMonitor(_ monitor: UbiquityContainerMonitor, needsConflictResolutionFor url: URL, versions: [NSFileVersion], completion: @escaping (ConflictResolution) -> ()) {
        guard let delegate else {
            log(.warn, "Conflicts were encountered for \(url), set a delegate to handle it properly. It will be ignored for now")
            completion(.ignore)
            return
        }

        delegate.shushFilesNeedsConflictResolution(for: url, versions: versions) { resolution in
            completion(resolution)
        }
    }
}

extension ShushFiles: Loggable {
    var logTag: String {
        return "FileArray(\(baseURL))"
    }
}
