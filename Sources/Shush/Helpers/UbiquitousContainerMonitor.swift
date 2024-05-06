//
//  File.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

internal protocol UbiquityContainerMonitorDelegate: NSObjectProtocol {
    func ubiquityContainerMonitor(_ monitor: UbiquityContainerMonitor, inserted: [URL], updated: [URL], removed: [URL])
    func ubiquityContainerMonitor(_ monitor: UbiquityContainerMonitor, needsConflictResolutionFor url: URL, versions: [NSFileVersion], completion: @escaping (ConflictResolution) -> ())
}

// https://developer.apple.com/documentation/uikit/documents_data_and_pasteboard/synchronizing_documents_in_the_icloud_environment
// https://github.com/drewmccormack/SwiftCloudDrive/blob/main/Sources/SwiftCloudDrive/MetadataMonitor.swift
class UbiquityContainerMonitor {
    // MARK: Init
    init(baseURL: URL, fileExtension: String?) {
        self.baseURL = baseURL.standardizedFileURL
        self.fileExtension = fileExtension
        
        metadataQuery = NSMetadataQuery()
        metadataQuery.notificationBatchingInterval = 3.0
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope, NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = queryPredicate

        NotificationCenter.default.addObserver(
            self, selector: #selector(self.processChanges),
            name: .NSMetadataQueryDidFinishGathering, object: metadataQuery
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(self.processChanges),
            name: .NSMetadataQueryDidUpdate, object: metadataQuery
        )
        DispatchQueue.main.async {
            self.metadataQuery.start()
        }
    }
    
    deinit {
        metadataQuery.disableUpdates()
        metadataQuery.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: metadataQuery)
    }

    // MARK: Public properties
    weak var delegate: UbiquityContainerMonitorDelegate?
    let baseURL: URL
    let fileExtension: String?

    // MARK: Query properties
    private var visibleItems: [NSMetadataItem.Item] = []
    private let metadataQuery: NSMetadataQuery
    private var queryPredicate: NSPredicate {
        var predicates = [NSPredicate]()
        // is in the proper path
        predicates.append(NSPredicate(format: "%K.path CONTAINS %@",
            NSMetadataItemURLKey, baseURL.path
        ))
        if let fileExtension {
            // has the expected extension
            predicates.append(NSPredicate(format: "%K.pathExtension = %@",
                NSMetadataItemURLKey, fileExtension
            ))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    // MARK: Updates handling
    @objc private func processChanges() {
        guard !Thread.isMainThread else {
            DispatchQueue.global(qos: .utility).async {
                self.processChanges()
            }
            return
        }

        let items = metadataQuery.items
        log(.info, "Processing changes, \(items.count) items found")

        // Distinguish kinds
        let itemsWithConflicts = items.filter(\.hasConflicts)
        let itemsWithoutConflicts = items.filter { !$0.hasConflicts }
        let itemsToDownload = itemsWithoutConflicts.filter { $0.availability != .upToDate && !$0.downloading }
        let visibleItems = itemsWithoutConflicts.filter { $0.availability != .notAvailable }
        
        // Process
        resolveConflicts(for: itemsWithConflicts.map(\.url))
        downloadItems(at: itemsToDownload.map(\.url))

        // Inform observer
        let changes = visibleItems.difference(from: self.visibleItems).changes
        DispatchQueue.main.async {
            self.visibleItems = visibleItems
            self.delegate?.ubiquityContainerMonitor(
                self,
                inserted: changes.inserted.map(\.url),
                updated: changes.updated.map(\.url),
                removed: changes.removed.map(\.url)
            )
        }
    }
    
    private func downloadItems(at urls: [URL]) {
        log(.info, "Downloading \(urls.count) items")
        for url in urls {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
            } catch {
                log(.warn, "Failed to start downloading file at \(url): \(error)")
            }
        }
    }
    
    // MARK: Conflicts handling
    private func resolveConflicts(for urls: [URL]) {
        log(.info, "Resolving conflicts for \(urls.count) items")
        if urls.isEmpty { return }
        
        let group = DispatchGroup()
        for url in urls {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                do {
                    try self.resolveConflicts(for: url)
                }
                catch {
                    self.log(.error, "Error while solving conflict for \(url): \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.log(.info, "Finished resolving conflicts")
        }
    }
    
    private func resolveConflicts(for url: URL) throws {
        try CoordinatedFileManager().coordinate(.writingIntent(with: url, options: .forDeleting)) { updatedURL in
            let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: updatedURL) ?? []
            let current = NSFileVersion.currentVersionOfItem(at: updatedURL)!

            var resolution: ConflictResolution = .ignore
            if let delegate = self.delegate {
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.main.async {
                    delegate.ubiquityContainerMonitor(self, needsConflictResolutionFor: url, versions: versions) { r in
                        resolution = r
                        group.leave()
                    }
                }
                group.wait()
            }
            
            switch resolution {
            case .ignore:
                break

            case .deleteOthers:
                try NSFileVersion.removeOtherVersionsOfItem(at: updatedURL)
                
            case .renameOthers:
                let directory = try! CoordinatedFileManager().exists(at: updatedURL).isDirectory
                let otherVersions = versions.filter { $0 != current }
                for otherVersion in otherVersions {
                    do {
                        let deduplicatedURL = updatedURL.deduplicatedURL(directory: directory)
                        try otherVersion.replaceItem(at: deduplicatedURL, options: .byMoving)
                        otherVersion.isResolved = true
                    }
                }

            case .keep(let version):
                let otherVersions = versions.filter { $0 != version }
                try otherVersions.forEach { try $0.remove() }
            }

            let remainingVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: updatedURL)
            remainingVersions?.forEach { $0.isResolved = true }
        }
    }
}

extension UbiquityContainerMonitor: Loggable {
    var logTag: String {
        return "UbiquityContainerMonitor(\(baseURL))"
    }
}
