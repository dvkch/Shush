//
//  File.swift
//  
//
//  Created by syan on 10/05/2024.
//

import Foundation

internal struct StandardizedURL {
    private(set) var url: URL

    init(url: URL) {
        // we cannot directly use `standardizedFileURL` because it needs the file to exist. when standardizing URLs for a deleted
        // file in an existing directory, the following code allows for proper standardization
        self.url = url
            .deletingLastPathComponent()
            .standardizedFileURL
            .appendingPathComponent(url.lastPathComponent)
    }
}

extension StandardizedURL: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: StandardizedURL, rhs: StandardizedURL) -> Bool {
        return lhs.url == rhs.url
    }
}
