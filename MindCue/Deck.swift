import Foundation

struct Deck: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let language: String
    let category: String
    let isPublic: Bool
    let isStatic: Bool
    // let createdAt: String
}

struct DecksResponse: Codable {
    let success: Bool
    let count: Int
    let data: [Deck]
} 