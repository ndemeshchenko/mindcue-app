import Foundation

class StudyingPlan: ObservableObject {
    // Session metadata
    let sessionId: String
    let deckId: String
    let startTime: Date
    var endTime: Date?
    
    // Session state
    @Published var isSessionComplete: Bool = false
    
    // Session statistics
    @Published var totalCards: Int = 0
    @Published var cardsReviewed: Int = 0
    @Published var correctResponses: Int = 0
    @Published var incorrectResponses: Int = 0
    
    init(deckId: String, sessionId: String, totalCards: Int, cardsReviewed: Int = 0, correctResponses: Int = 0, incorrectResponses: Int = 0, startTime: Date = Date(), isSessionComplete: Bool = false) {
        self.sessionId = sessionId
        self.deckId = deckId
        self.startTime = startTime
        self.totalCards = totalCards
        self.cardsReviewed = cardsReviewed
        self.correctResponses = correctResponses
        self.incorrectResponses = incorrectResponses
        self.isSessionComplete = isSessionComplete
    }
    
    // Complete the session
    func completeSession() {
        isSessionComplete = true
        endTime = Date()
    }
    
    // Get session summary
    var sessionSummary: SessionSummary {
        return SessionSummary(
            sessionId: sessionId,
            deckId: deckId,
            startTime: startTime,
            endTime: endTime ?? Date(),
            totalCards: totalCards,
            cardsReviewed: cardsReviewed,
            correctResponses: correctResponses,
            incorrectResponses: incorrectResponses
        )
    }
}

// StudyCard is a session-specific version of a Card
class StudyCard: Identifiable, ObservableObject {
    let id: String
    let deckId: String
    let front: String
    let back: String
    let examples: [String]?
    let tags: [String]?
    let difficulty: Int
    
    // Session-specific state
    @Published var hasBeenReviewed: Bool = false
    @Published var lastResponseQuality: Int?
    
    init(id: String, deckId: String, front: String, back: String, examples: [String]?, tags: [String]?, difficulty: Int) {
        self.id = id
        self.deckId = deckId
        self.front = front
        self.back = back
        self.examples = examples
        self.tags = tags
        self.difficulty = difficulty
    }
    
    // Helper to determine if the response was correct (quality >= 3 is considered correct)
    var wasLastResponseCorrect: Bool? {
        guard let quality = lastResponseQuality else { return nil }
        return quality >= 3
    }
}

// Session summary for analytics and history
struct SessionSummary: Codable, Identifiable {
    let id: UUID
    let sessionId: String
    let deckId: String
    let startTime: Date
    let endTime: Date
    let totalCards: Int
    let cardsReviewed: Int
    let correctResponses: Int
    let incorrectResponses: Int
    
    var accuracy: Double {
        guard cardsReviewed > 0 else { return 0 }
        return Double(correctResponses) / Double(cardsReviewed)
    }
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    init(sessionId: String, deckId: String, startTime: Date, endTime: Date, totalCards: Int, cardsReviewed: Int, correctResponses: Int, incorrectResponses: Int) {
        self.id = UUID()
        self.sessionId = sessionId
        self.deckId = deckId
        self.startTime = startTime
        self.endTime = endTime
        self.totalCards = totalCards
        self.cardsReviewed = cardsReviewed
        self.correctResponses = correctResponses
        self.incorrectResponses = incorrectResponses
    }
} 