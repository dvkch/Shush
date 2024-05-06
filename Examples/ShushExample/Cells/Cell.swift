//
//  Cell.swift
//  ShushExample
//
//  Created by syan on 28/04/2024.
//

import UIKit
import Shush

class Cell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Properties
    enum Content {
        case color(Color)
        case word(Word)
        case newWord
        case image(ShushFile<Image>)
        case newImage
    }
    var content: Content? {
        didSet {
            updateContent()
        }
    }

    // MARK: Content
    private func updateContent() {
        guard let content else { return }
        switch content {
        case .color(let color):
            textLabel?.text = color.rawValue
            textLabel?.textColor = color.uiColor
            detailTextLabel?.text = nil
            accessoryType = .none

        case .word(let word):
            textLabel?.text = word.value
            textLabel?.textColor = .label
            detailTextLabel?.text = nil
            accessoryType = .none
            
        case .newWord:
            textLabel?.text = "Add a random word..."
            textLabel?.textColor = .label
            detailTextLabel?.text = nil
            accessoryType = .none

        case .image(let image):
            textLabel?.text = image.partial.id.uuidString
            textLabel?.textColor = .label
            detailTextLabel?.text = image.partial.date.description
            accessoryType = .disclosureIndicator

        case .newImage:
            textLabel?.text = "Add a new image..."
            textLabel?.textColor = .label
            detailTextLabel?.text = nil
            accessoryType = .none
        }
    }
}
