//
//  ViewController.swift
//  ShushExample
//
//  Created by syan on 28/04/2024.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: ViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(Cell.self, forCellReuseIdentifier: "Cell")
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.colorChanged), name: .colorChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.wordsChanged), name: .wordsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.imagesChanged), name: .imagesChanged, object: nil)
    }
    
    // MARK: Views
    private let tableView = UITableView()
    
    // MARK: Actions
    @objc private func colorChanged() {
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(integer: Section.color.rawValue), with: .automatic)
        tableView.endUpdates()
    }
    
    @objc private func wordsChanged() {
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(integer: Section.words.rawValue), with: .automatic)
        tableView.endUpdates()
    }
    
    @objc private func imagesChanged() {
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(integer: Section.images.rawValue), with: .automatic)
        tableView.endUpdates()
    }
    
    // MARK: Content
    private enum Section: Int, CaseIterable {
        case color
        case words
        case images
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .color:
            return 1
        case .words:
            return Preferences.shared.words.count + 1
        case .images:
            return Preferences.shared.images.files.count + 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! Cell
        switch Section(rawValue: indexPath.section)! {
        case .color:
            cell.content = .color(Preferences.shared.color)

        case .words:
            if indexPath.row < Preferences.shared.words.count {
                cell.content = .word(Preferences.shared.words[indexPath.row])
            }
            else {
                cell.content = .newWord
            }

        case .images:
            if indexPath.row < Preferences.shared.images.files.count {
                cell.content = .image(Preferences.shared.images.files[indexPath.row])
            }
            else {
                cell.content = .newImage
            }
        }
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? Cell, let content = cell.content else { return }
        
        switch content {
        case .color(let color):
            Preferences.shared.color = Color.allCases.filter { $0 != color }.randomElement()!

        case .word(let word):
            Preferences.shared.removeWord(word)

        case .newWord:
            // TODO: generate random word
            
        case .image(let image):
            Preferences.shared.images.remove([image])
            
        case .newImage:
            // TODO: show image import
        }
    }
}
