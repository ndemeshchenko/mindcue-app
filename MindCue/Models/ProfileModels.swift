import Foundation

// Main profile response model
struct ProfileResponse: Codable {
    let success: Bool
    let data: ProfileData
}

// Profile data structure
struct ProfileData: Codable {
    let user: UserProfile
    let studyPlans: [StudyPlan]
    let mostRecentPlan: StudyPlan?
}

// User profile information
struct UserProfile: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let role: String
    let createdAt: String
    let updatedAt: String
    
    // Computed property to format the join date
    var formattedJoinDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: createdAt) {
            dateFormatter.dateFormat = "MMMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        return "Unknown date"
    }
}

// Study plan model
struct StudyPlan: Codable, Identifiable {
    let id: String
    let deckId: DeckInfo
    let deckName: String
    let isActive: Bool
    let settings: StudyPlanSettings?
    let createdAt: String?
    let updatedAt: String?
    
    // Format the creation date
    var formattedCreationDate: String {
        guard let dateString = createdAt else { return "N/A" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        return "Unknown date"
    }
}

// Deck information
struct DeckInfo: Codable {
    let _id: String
    let name: String
    let description: String?
}

// Study plan settings
struct StudyPlanSettings: Codable {
    let newCardsPerDay: Int
    let learningSteps: [Int]
    let relearningSteps: [Int]
    let initialInterval: Int
    let easyInterval: Int
    let easyBonus: Double
    let intervalModifier: Double
    let hardIntervalModifier: Double
    let lapseNewInterval: Double
    let enableFuzzing: Bool
    let fuzzingPercentage: Double
    let enableFSRS: Bool
    let desiredRetention: Double
} 