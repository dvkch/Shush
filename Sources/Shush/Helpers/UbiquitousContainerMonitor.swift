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
}

// https://developer.apple.com/documentation/uikit/documents_data_and_pasteboard/synchronizing_documents_in_the_icloud_environment
// https://github.com/drewmccormack/SwiftCloudDrive/blob/main/Sources/SwiftCloudDrive/MetadataMonitor.swift
class UbiquityContainerMonitor {
    // MARK: Init
    init(baseURL: URL, fileExtension: String?, interval: TimeInterval) {
        self.baseURL = baseURL.standardizedFileURL
        self.fileExtension = fileExtension
        
        metadataQuery = NSMetadataQuery()
        metadataQuery.notificationBatchingInterval = interval
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

        // Distinguish kinds
        let itemsToDownload = items.filter { $0.availability != .upToDate && !$0.downloading }
        let visibleItems = items.filter { $0.availability != .notAvailable }

        // Process
        downloadItems(at: itemsToDownload.map(\.url))

        // Inform observer
        let diff = visibleItems.difference(from: self.visibleItems)
        guard diff.isNotEmpty else { return }

        let changes = diff.changes
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
        guard urls.isNotEmpty else { return }

        log(.info, "Downloading \(urls.count) items")
        for url in urls {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
            } catch {
                log(.warn, "Failed to start downloading file at \(url): \(error)")
            }
        }
    }
}

extension UbiquityContainerMonitor: Loggable {
    var logTag: String {
        return "UbiquityContainerMonitor(\(baseURL))"
    }
}
