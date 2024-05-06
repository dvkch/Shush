//
//  Word.swift
//  ShushExample
//
//  Created by syan on 28/04/2024.
//

import Foundation

struct Word: Identifiable, Codable {
    init(value: String) {
        self.date = Date()
        self.value = value
    }
    let date: Date
    let value: String
    var id: String { value }
}
