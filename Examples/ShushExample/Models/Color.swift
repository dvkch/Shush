//
//  Color.swift
//  ShushExample
//
//  Created by syan on 28/04/2024.
//

import UIKit

enum Color: String, Codable, CaseIterable, Equatable {
    case blue   = "blue"
    case green  = "green"
    case yellow = "yellow"
    case orange = "orange"
    case red    = "red"
    case purple = "purple"
    
    var uiColor: UIColor {
        switch self {
        case .blue:     return .systemBlue
        case .green:    return .systemGreen
        case .yellow:   return .systemYellow
        case .orange:   return .systemOrange
        case .red:      return .systemRed
        case .purple:   return .systemPurple
        }
    }
}
