//
//  Image.swift
//  ShushExample
//
//  Created by syan on 28/04/2024.
//

import Foundation
import Shush
import UIKit

struct Image: Codable {
    init(image: UIImage) {
        self.id = UUID()
        self.date = Date()
        self.imageData = image.pngData()!
    }

    let id: UUID
    let date: Date
    let imageData: Data
}

struct ImageMetadata: Codable {
    let id: UUID
    let date: Date
}

// For simplicity an image file is represented as JSON. 
// You could also choose to:
// - encode PNG data
// - decode metadata (partial version) directly from the PNG data
// - decode a type containing both UIImage + metadata directly from the PNG data
extension Image: Persistable {
    static func decodePersisted(_ data: Data) throws -> Image {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        return try decoder.decode(Self.self, from: data)
    }
    
    static func decodePersistedPartially(_ data: Data) throws -> ImageMetadata {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        return try decoder.decode(ImageMetadata.self, from: data)
    }
    
    static func encodePersisted(_ data: Image) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        return try encoder.encode(data)
    }
    
    static var fileExtension: String {
        "shushImage"
    }
    
    var partialRepresentation: ImageMetadata {
        return .init(id: id, date: date)
    }
}

extension Image: PersistableIdentifiable {
    static func suggestedFilename(for persistable: Image) -> String {
        return persistable.id.uuidString
    }
}

extension ImageMetadata: PersistablePartial {}
