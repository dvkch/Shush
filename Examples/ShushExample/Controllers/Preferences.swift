//
//  Preferences.swift
//  ShushExample
//
//  Created by syan on 28/04/2024.
//

import Foundation
import Shush

extension Notification.Name {
    static let colorChanged = Notification.Name("colorChanged")
    static let wordsChanged = Notification.Name("wordsChanged")
    static let imagesChanged = Notification.Name("imagesChanged")
}

class Preferences {
    
    // MARK: Init
    static let shared = Preferences()
    private init() { }
    
    // MARK: Properties
    @ShushValue(key: "color", defaultValue: .blue, notification: .colorChanged)
    var color: Color
    
    @ShushValues(prefix: "words", sortedBy: \.date, order: .desc, notification: .wordsChanged)
    var words: [Word]
    func addWord(_ word: String) {
        _words.insert([.init(value: word)])
    }
    func removeWord(_ word: Word) {
        _words.remove(word)
    }
    
    private static let imagesURL: URL = try! FileManager.default
        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("Images", isDirectory: true)
    let images = ShushFiles<Image, Date>(baseURL: Preferences.imagesURL, sortedBy: \.partial.date, order: .desc, notification: .imagesChanged)
}
