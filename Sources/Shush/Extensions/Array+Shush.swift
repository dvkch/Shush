//
//  Array+Shush.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation

internal extension Collection {
    var isNotEmpty: Bool {
        return !isEmpty
    }
}

internal extension Sequence {
    func sorted<V: Comparable>(by path: KeyPath<Element, V>, ascending: Bool = true) -> [Self.Element] {
        return self.sorted { e1, e2 in
            return (e1[keyPath: path] < e2[keyPath: path]) == ascending
        }
    }
}

internal extension MutableCollection where Self : RandomAccessCollection {
    mutating func sort<V: Comparable>(by path: KeyPath<Element, V>, ascending: Bool = true) {
        self.sort { e1, e2 in
            return (e1[keyPath: path] < e2[keyPath: path]) == ascending
        }
    }
}
