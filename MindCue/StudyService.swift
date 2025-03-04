import Foundation
import OSLog

class StudyService: ObservableObject {
    static let shared = StudyService()
    
    private let logger = Logger(subsystem: "com.mdem.MindCue", category: "StudyService")
    private let authService = AuthService.shared
    private let baseURL = "https://d854-195-240-134-68.ngrok-free.app/api/user"
    
    @Published var currentPlan: StudyingPlan?
    @Published var currentSessionId: String?
    @Published var currentCard: StudyCard?
    @Published var currentCardIndex: String?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var sessionStats: SessionStats?
    @Published var authenticationFailed = false
    
    // MARK: - Authentication Handling
    
    // Handle authentication failure
    func handleAuthenticationFailure() {
        logger.warning("Authentication failure detected, signing out user")
        
        // Sign out the user
        authService.signOut()
        
        // Update UI state
        DispatchQueue.main.async {
            self.authenticationFailed = true
            self.error = NSError(
                domain: "com.mdem.MindCue",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Your session has expired. Please sign in again."]
            )
        }
    }
    
    // Reset authentication failure state
    func resetAuthenticationFailure() {
        DispatchQueue.main.async {
            self.authenticationFailed = false
            self.error = nil
        }
    }
    
    // Start a new study session for a deck
    func startStudySession(deckId: String) async {
        await MainActor.run {
            isLoading = true
            error = nil
            currentCard = nil
        }
        
        do {
            // Start a session with the API
            let sessionResponse = try await startSession(deckId: deckId)
            
            // Create a new studying plan
            await MainActor.run {
                self.currentSessionId = sessionResponse.sessionId
                self.currentPlan = StudyingPlan(
                    deckId: deckId,
                    sessionId: sessionResponse.sessionId,
                    totalCards: sessionResponse.totalCards,
                    newCards: sessionResponse.newCards,
                    reviewCards: sessionResponse.reviewCards
                )
                self.logger.info("Created new study session with ID: \(sessionResponse.sessionId)")
                
                // Fetch the first card
                Task {
                    await self.fetchNextCard()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.logger.error("Failed to start study session: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // Fetch the next card in the session
    func fetchNextCard(forceUpdate: Bool = false) async {
        guard let sessionId = currentSessionId else {
            logger.error("Attempted to fetch next card with no active session ID")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let nextCardResponse = try await getNextCard(sessionId: sessionId, forceUpdate: forceUpdate)
            
            await MainActor.run {
                // Store the cardIndex from the response
                self.currentCardIndex = nextCardResponse.cardIndex
                
                if let cardData = nextCardResponse.card {
                    self.currentCard = StudyCard(
                        id: cardData.id,
                        deckId: cardData.deckId,
                        front: cardData.front,
                        back: cardData.back,
                        examples: cardData.examples,
                        tags: cardData.tags,
                        difficulty: cardData.difficulty ?? 3,
                        partOfSpeech: cardData.partOfSpeech
                    )
                    
                    // Update session progress if available
                    if let progress = nextCardResponse.progress {
                        self.currentPlan?.cardsReviewed = progress.cardsReviewed
                        self.currentPlan?.totalCards = progress.totalCards
                    }
                    
                    self.logger.info("Fetched next card: \(cardData.id), index: \(nextCardResponse.cardIndex ?? "unknown")")
                } else {
                    // No more cards, session is complete
                    self.currentCard = nil
                    self.currentCardIndex = nil
                    self.currentPlan?.isSessionComplete = true
                    self.logger.info("No more cards in session, marking as complete")
                    
                    // Fetch final session stats
                    Task {
                        await self.fetchSessionStats()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.logger.error("Failed to fetch next card: \(error.localizedDescription)")
                
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        self.logger.error("Key not found: \(key.stringValue), context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        self.logger.error("Value not found: \(type), context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        self.logger.error("Type mismatch: \(type), context: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        self.logger.error("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        self.logger.error("Unknown decoding error")
                    }
                }
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // Record a response for the current card
    func recordResponse(quality: Int) async {
        guard let sessionId = currentSessionId, let card = currentCard else {
            logger.warning("Attempted to record a response with no active session or card")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Submit the answer to the API
            let answerResponse = try await submitAnswer(
                sessionId: sessionId,
                cardIndex: currentCardIndex ?? card.id,
                quality: quality
            )
            
            await MainActor.run {
                // Update session plan with the response if available
                if let stats = answerResponse.stats {
                    currentPlan?.cardsReviewed = stats.cardsReviewed
                    currentPlan?.correctResponses = stats.correctResponses
                    currentPlan?.incorrectResponses = stats.incorrectResponses
                }
                
                // Mark the current card as reviewed
                card.hasBeenReviewed = true
                card.lastResponseQuality = quality
                
                logger.info("Recorded response with quality \(quality) for card \(card.id)")
                
                // Fetch the next card
                Task {
                    await self.fetchNextCard()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.logger.error("Failed to submit answer: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // Fetch session statistics
    func fetchSessionStats() async {
        guard let sessionId = currentSessionId else {
            logger.error("Attempted to fetch session stats with no active session ID")
            return
        }
        
        do {
            let stats = try await getSessionStats(sessionId: sessionId)
            
            await MainActor.run {
                self.sessionStats = stats
                self.logger.info("Fetched session stats: \(stats.cardsReviewed) cards reviewed with \(stats.accuracy)% accuracy")
            }
        } catch {
            await MainActor.run {
                self.logger.error("Failed to fetch session stats: \(error.localizedDescription)")
            }
        }
    }
    
    // End the current study session
    func endStudySession() {
        DispatchQueue.main.async {
            self.currentPlan = nil
            self.currentSessionId = nil
            self.currentCard = nil
            self.sessionStats = nil
            self.logger.info("Study session ended")
        }
    }
    
    // MARK: - API Calls
    
    // Start a new session
    private func startSession(deckId: String) async throws -> SessionResponse {
        guard let url = URL(string: "\(baseURL)/decks/\(deckId)/start") else {
            logger.error("Invalid URL")
            throw URLError(.badURL)
        }
        
        logger.info("Starting session for deck \(deckId)")
        
        // Try up to 2 times (original attempt + 1 retry after token refresh)
        for attemptCount in 1...2 {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Add auth token
            if let token = authService.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                logger.debug("Using auth token: \(token.prefix(10))...")
            } else {
                logger.warning("No auth token available, request may fail")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check response status
                if let httpResponse = response as? HTTPURLResponse {
                    logger.info("HTTP Status Code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 401 {
                        logger.warning("Unauthorized request (401) on attempt \(attemptCount)")
                        
                        if attemptCount == 1 {
                            // On first attempt, notify the user and try again
                            logger.info("Authentication token may be expired, notifying user")
                            
                            // Handle authentication failure
                            handleAuthenticationFailure()
                            
                            // Continue to the next attempt
                            continue
                        } else {
                            // If we've already tried to refresh, give up
                            throw NSError(
                                domain: "com.mdem.MindCue",
                                code: 401,
                                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                            )
                        }
                    } else if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                        logger.error("API error: \(httpResponse.statusCode)")
                        throw NSError(
                            domain: "com.mdem.MindCue",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to start session. Server returned \(httpResponse.statusCode)"]
                        )
                    }
                }
                
                // For debugging
                let responseString = String(data: data, encoding: .utf8) ?? "unable to decode"
                logger.debug("Received data: \(responseString)")
                
                // Try to parse the response
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .useDefaultKeys
                    
                    logger.debug("Attempting to decode SessionResponse")
                    let sessionResponse = try decoder.decode(SessionResponse.self, from: data)
                    logger.info("Successfully decoded SessionResponse with sessionId: \(sessionResponse.sessionId)")
                    return sessionResponse
                } catch {
                    logger.error("Failed to decode session response: \(error.localizedDescription)")
                    
                    // Provide more detailed error information
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            logger.error("Key not found: \(key.stringValue), context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            logger.error("Value not found: \(type), context: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            logger.error("Type mismatch: \(type), context: \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            logger.error("Data corrupted: \(context.debugDescription)")
                        @unknown default:
                            logger.error("Unknown decoding error")
                        }
                    }
                    
                    logger.error("Response data: \(responseString)")
                    throw error
                }
            } catch {
                // If this is the last attempt, or the error is not related to authentication, rethrow
                if attemptCount == 2 || (error as NSError).code != 401 {
                    logger.error("Network error on attempt \(attemptCount): \(error.localizedDescription)")
                    throw error
                }
                // Otherwise, continue to the next attempt
            }
        }
        
        // This should never be reached due to the throws above, but Swift requires it
        throw NSError(
            domain: "com.mdem.MindCue",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error starting session"]
        )
    }
    
    // Get the next card in a session
    private func getNextCard(sessionId: String, forceUpdate: Bool = false) async throws -> NextCardResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/study/session/\(sessionId)/next")
        
        // Add forceUpdate query parameter if needed
        if forceUpdate {
            urlComponents?.queryItems = [URLQueryItem(name: "forceUpdate", value: "true")]
        }
        
        guard let url = urlComponents?.url else {
            logger.error("Invalid URL")
            throw URLError(.badURL)
        }
        
        logger.info("Fetching next card for session \(sessionId)")
        
        // Try up to 2 times (original attempt + 1 retry after token refresh)
        for attemptCount in 1...2 {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Add auth token
            if let token = authService.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                logger.debug("Using auth token: \(token.prefix(10))...")
            } else {
                logger.warning("No auth token available for request")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check response status
                if let httpResponse = response as? HTTPURLResponse {
                    logger.info("HTTP Status Code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 401 {
                        // Authentication error
                        logger.warning("Authentication error (401) on attempt \(attemptCount)")
                        
                        if attemptCount == 1 {
                            // On first attempt, try to refresh token by signing out and showing an alert
                            logger.info("Authentication token may be expired, notifying user")
                            
                            // Handle authentication failure
                            handleAuthenticationFailure()
                            
                            // Continue to the next attempt
                            continue
                        } else {
                            // If we've already tried to refresh, give up
                            throw NSError(
                                domain: "com.mdem.MindCue",
                                code: 401,
                                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                            )
                        }
                    } else if httpResponse.statusCode != 200 {
                        logger.error("API error: \(httpResponse.statusCode)")
                        throw NSError(
                            domain: "com.mdem.MindCue",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to fetch next card. Server returned \(httpResponse.statusCode)"]
                        )
                    }
                }
                
                // For debugging
                let responseString = String(data: data, encoding: .utf8) ?? "unable to decode"
                logger.debug("Received data: \(responseString)")
                
                // Try to parse the response
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .useDefaultKeys
                    
                    logger.debug("Attempting to decode NextCardResponse")
                    let nextCardResponse = try decoder.decode(NextCardResponse.self, from: data)
                    logger.info("Successfully decoded NextCardResponse")
                    return nextCardResponse
                } catch {
                    logger.error("Failed to decode next card response: \(error.localizedDescription)")
                    
                    // Provide more detailed error information
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            logger.error("Key not found: \(key.stringValue), context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            logger.error("Value not found: \(type), context: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            logger.error("Type mismatch: \(type), context: \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            logger.error("Data corrupted: \(context.debugDescription)")
                        @unknown default:
                            logger.error("Unknown decoding error")
                        }
                    }
                    
                    logger.error("Response data: \(responseString)")
                    throw error
                }
            } catch {
                // If this is the last attempt, or the error is not related to authentication, rethrow
                if attemptCount == 2 || (error as NSError).code != 401 {
                    logger.error("Network error on attempt \(attemptCount): \(error.localizedDescription)")
                    throw error
                }
                // Otherwise, continue to the next attempt
            }
        }
        
        // This should never be reached due to the throws above, but Swift requires it
        throw NSError(
            domain: "com.mdem.MindCue",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error fetching next card"]
        )
    }
    
    // Submit an answer for a card
    private func submitAnswer(sessionId: String, cardIndex: String, quality: Int) async throws -> AnswerResponse {
        guard let url = URL(string: "\(baseURL)/study/session/\(sessionId)/answer") else {
            logger.error("Invalid URL")
            throw URLError(.badURL)
        }
        
        logger.info("Submitting answer for card with index \(cardIndex) in session \(sessionId) with quality \(quality)")
        
        // Try up to 2 times (original attempt + 1 retry after token refresh)
        for attemptCount in 1...2 {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Add auth token
            if let token = authService.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                logger.debug("Using auth token: \(token.prefix(10))...")
            } else {
                logger.warning("No auth token available, request may fail")
            }
            
            // Create request body
            let body = [
                "cardIndex": cardIndex, // Use cardIndex parameter name as required by the API
                "quality": quality
            ] as [String : Any]
            
            // Log the request body for debugging
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("Request body: \(jsonString)")
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check response status
                if let httpResponse = response as? HTTPURLResponse {
                    logger.info("HTTP Status Code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 401 {
                        logger.warning("Unauthorized request (401) on attempt \(attemptCount)")
                        
                        if attemptCount == 1 {
                            // On first attempt, notify the user and try again
                            logger.info("Authentication token may be expired, notifying user")
                            
                            // Handle authentication failure
                            handleAuthenticationFailure()
                            
                            // Continue to the next attempt
                            continue
                        } else {
                            // If we've already tried to refresh, give up
                            throw NSError(
                                domain: "com.mdem.MindCue",
                                code: 401,
                                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                            )
                        }
                    } else if httpResponse.statusCode != 200 {
                        logger.error("API error: \(httpResponse.statusCode)")
                        throw NSError(
                            domain: "com.mdem.MindCue",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to submit answer. Server returned \(httpResponse.statusCode)"]
                        )
                    }
                }
                
                // For debugging
                let responseString = String(data: data, encoding: .utf8) ?? "unable to decode"
                logger.debug("Received data: \(responseString)")
                
                // Try to parse the response
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .useDefaultKeys
                    
                    logger.debug("Attempting to decode AnswerResponse")
                    let answerResponse = try decoder.decode(AnswerResponse.self, from: data)
                    logger.info("Successfully decoded AnswerResponse")
                    return answerResponse
                } catch {
                    logger.error("Failed to decode answer response: \(error.localizedDescription)")
                    
                    // Provide more detailed error information
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            logger.error("Key not found: \(key.stringValue), context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            logger.error("Value not found: \(type), context: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            logger.error("Type mismatch: \(type), context: \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            logger.error("Data corrupted: \(context.debugDescription)")
                        @unknown default:
                            logger.error("Unknown decoding error")
                        }
                    }
                    
                    logger.error("Response data: \(responseString)")
                    throw error
                }
            } catch {
                // If this is the last attempt, or the error is not related to authentication, rethrow
                if attemptCount == 2 || (error as NSError).code != 401 {
                    logger.error("Network error on attempt \(attemptCount): \(error.localizedDescription)")
                    throw error
                }
                // Otherwise, continue to the next attempt
            }
        }
        
        // This should never be reached due to the throws above, but Swift requires it
        throw NSError(
            domain: "com.mdem.MindCue",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error submitting answer"]
        )
    }
    
    // Get session statistics
    private func getSessionStats(sessionId: String) async throws -> SessionStats {
        guard let url = URL(string: "\(baseURL)/study/session/\(sessionId)/stats") else {
            logger.error("Invalid URL")
            throw URLError(.badURL)
        }
        
        logger.info("Fetching stats for session \(sessionId)")
        
        // Try up to 2 times (original attempt + 1 retry after token refresh)
        for attemptCount in 1...2 {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Add auth token
            if let token = authService.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                logger.debug("Using auth token: \(token.prefix(10))...")
            } else {
                logger.warning("No auth token available, request may fail")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check response status
                if let httpResponse = response as? HTTPURLResponse {
                    logger.info("HTTP Status Code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 401 {
                        logger.warning("Unauthorized request (401) on attempt \(attemptCount)")
                        
                        if attemptCount == 1 {
                            // On first attempt, notify the user and try again
                            logger.info("Authentication token may be expired, notifying user")
                            
                            // Handle authentication failure
                            handleAuthenticationFailure()
                            
                            // Continue to the next attempt
                            continue
                        } else {
                            // If we've already tried to refresh, give up
                            throw NSError(
                                domain: "com.mdem.MindCue",
                                code: 401,
                                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                            )
                        }
                    } else if httpResponse.statusCode != 200 {
                        logger.error("API error: \(httpResponse.statusCode)")
                        throw NSError(
                            domain: "com.mdem.MindCue",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to fetch session stats. Server returned \(httpResponse.statusCode)"]
                        )
                    }
                }
                
                // For debugging
                let responseString = String(data: data, encoding: .utf8) ?? "unable to decode"
                logger.debug("Received data: \(responseString)")
                
                // Try to parse the response
                do {
                    let statsResponse = try JSONDecoder().decode(SessionStatsResponse.self, from: data)
                    return statsResponse.stats
                } catch {
                    logger.error("Failed to decode stats response: \(error.localizedDescription)")
                    logger.error("Response data: \(responseString)")
                    throw error
                }
            } catch {
                // If this is the last attempt, or the error is not related to authentication, rethrow
                if attemptCount == 2 || (error as NSError).code != 401 {
                    logger.error("Network error on attempt \(attemptCount): \(error.localizedDescription)")
                    throw error
                }
                // Otherwise, continue to the next attempt
            }
        }
        
        // This should never be reached due to the throws above, but Swift requires it
        throw NSError(
            domain: "com.mdem.MindCue",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unknown error fetching session stats"]
        )
    }
}

// MARK: - API Response Models

struct SessionResponse: Codable {
    let success: Bool
    let sessionId: String
    let deckId: String
    let totalCards: Int
    let newCards: Int
    let reviewCards: Int
    let message: String?
    
    // Static logger for debugging
    private static let logger = Logger(subsystem: "com.mdem.MindCue", category: "SessionResponse")
    
    // Add CodingKeys to handle specific API response structure
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
    
    // Nested CodingKeys for data object
    enum DataCodingKeys: String, CodingKey {
        case sessionId
        case deckId
        case totalCards
        case newCards
        case reviewCards
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode success
        success = try container.decode(Bool.self, forKey: .success)
        
        // Try to decode top-level message if present
        let topLevelMessage = try container.decodeIfPresent(String.self, forKey: .message)
        
        // Access the data container
        let dataContainer = try container.nestedContainer(keyedBy: DataCodingKeys.self, forKey: .data)
        
        // Get values directly from the data container
        sessionId = try dataContainer.decode(String.self, forKey: .sessionId)
        
        deckId = try dataContainer.decode(String.self, forKey: .deckId)
        
        totalCards = try dataContainer.decode(Int.self, forKey: .totalCards)
        
        // Get new cards and review cards (with fallbacks if they're not present)
        if let count = try? dataContainer.decode(Int.self, forKey: .newCards) {
            newCards = count
        } else {
            newCards = 0
            SessionResponse.logger.warning("newCards not found in API response, defaulting to 0")
        }
        
        if let count = try? dataContainer.decode(Int.self, forKey: .reviewCards) {
            reviewCards = count
        } else {
            reviewCards = 0
            SessionResponse.logger.warning("reviewCards not found in API response, defaulting to 0")
        }
        
        // Try to decode message from data container, or use top-level message
        let dataMessage = try dataContainer.decodeIfPresent(String.self, forKey: .message)
        message = dataMessage ?? topLevelMessage
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        
        var dataContainer = container.nestedContainer(keyedBy: DataCodingKeys.self, forKey: .data)
        try dataContainer.encode(sessionId, forKey: .sessionId)
        try dataContainer.encode(deckId, forKey: .deckId)
        try dataContainer.encode(totalCards, forKey: .totalCards)
        try dataContainer.encode(newCards, forKey: .newCards)
        try dataContainer.encode(reviewCards, forKey: .reviewCards)
        try dataContainer.encodeIfPresent(message, forKey: .message)
    }
}

struct CardData: Codable {
    let id: String
    var deckId: String
    let front: String
    let back: String
    let examples: [String]?
    let tags: [String]?
    let difficulty: Int?
    let partOfSpeech: String?
    
    // Static logger for debugging
    private static let logger = Logger(subsystem: "com.mdem.MindCue", category: "CardData")
    
    // Add CodingKeys to handle specific API response structure
    enum CodingKeys: String, CodingKey {
        case id
        case fields
        case tags
        case isNew
    }
    
    // Nested CodingKeys for fields object
    enum FieldsCodingKeys: String, CodingKey {
        case Word
        case Definition
        case Dutch
        case English
        case Freq
        case Rank
        case partOfSpeech = "Part-of-Speech"
        case wordAudio = "Word Audio"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode id
        id = try container.decode(String.self, forKey: .id)
        
        // For now, we'll set a placeholder deckId
        // This will be set by the parent object
        deckId = ""
        
        do {
            // Decode fields
            let fieldsContainer = try container.nestedContainer(keyedBy: FieldsCodingKeys.self, forKey: .fields)
            
            // Use Word as front
            front = try fieldsContainer.decode(String.self, forKey: .Word)
            
            // Use Definition as back
            back = try fieldsContainer.decode(String.self, forKey: .Definition)
            
            // Try to decode Part-of-Speech if available
            partOfSpeech = try? fieldsContainer.decode(String.self, forKey: .partOfSpeech)
            
            // Use Dutch and English as examples
            do {
                let dutch = try fieldsContainer.decode(String.self, forKey: .Dutch)
                let english = try fieldsContainer.decode(String.self, forKey: .English)
                examples = [dutch, english]
            } catch {
                examples = nil
            }
        } catch {
            throw error
        }
        
        // Decode tags
        do {
            tags = try container.decodeIfPresent([String].self, forKey: .tags)
        } catch {
            tags = nil
        }
        
        // Default difficulty to 3
        difficulty = 3
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(tags, forKey: .tags)
        
        // We don't need to encode the nested structure for our internal use
    }
}

struct SessionProgress: Codable {
    let cardsReviewed: Int
    let totalCards: Int
    let remainingCards: Int
    
    // Add CodingKeys to handle potential differences in API response
    enum CodingKeys: String, CodingKey {
        case cardsReviewed
        case totalCards
        case remainingCards
        // Alternative keys
        case reviewed
        case total
        case remaining
        case cards_reviewed
        case total_cards
        case remaining_cards
    }
    
    // Custom initializer for creating a SessionProgress directly
    init(cardsReviewed: Int, totalCards: Int, remainingCards: Int) {
        self.cardsReviewed = cardsReviewed
        self.totalCards = totalCards
        self.remainingCards = remainingCards
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try different possible keys for cardsReviewed
        if let count = try container.decodeIfPresent(Int.self, forKey: .cardsReviewed) {
            cardsReviewed = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .reviewed) {
            cardsReviewed = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .cards_reviewed) {
            cardsReviewed = count
        } else {
            cardsReviewed = 0 // Default value
        }
        
        // Try different possible keys for totalCards
        if let count = try container.decodeIfPresent(Int.self, forKey: .totalCards) {
            totalCards = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .total) {
            totalCards = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .total_cards) {
            totalCards = count
        } else {
            totalCards = 0 // Default value
        }
        
        // Try different possible keys for remainingCards
        if let count = try container.decodeIfPresent(Int.self, forKey: .remainingCards) {
            remainingCards = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .remaining) {
            remainingCards = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .remaining_cards) {
            remainingCards = count
        } else {
            // Calculate remaining if not provided
            remainingCards = totalCards - cardsReviewed
        }
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cardsReviewed, forKey: .cardsReviewed)
        try container.encode(totalCards, forKey: .totalCards)
        try container.encode(remainingCards, forKey: .remainingCards)
    }
}

struct NextCardResponse: Codable {
    let success: Bool
    let card: CardData?
    let progress: SessionProgress?
    let message: String?
    let cardIndex: String?
    
    // Static logger for debugging
    private static let logger = Logger(subsystem: "com.mdem.MindCue", category: "NextCardResponse")
    
    // Add CodingKeys to handle specific API response structure
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
    
    // Nested CodingKeys for data object
    enum DataCodingKeys: String, CodingKey {
        case sessionComplete
        case cardIndex
        case progress
        case card
        case instructions
    }
    
    // Nested CodingKeys for progress object
    enum ProgressCodingKeys: String, CodingKey {
        case current
        case total
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode success
        success = try container.decode(Bool.self, forKey: .success)
        
        // Try to decode message if present
        message = try container.decodeIfPresent(String.self, forKey: .message)
        
        // Access the data container
        let dataContainer = try container.nestedContainer(keyedBy: DataCodingKeys.self, forKey: .data)
        
        // Extract the cardIndex if present - handle both String and Int types
        if let indexAsString = try? dataContainer.decodeIfPresent(String.self, forKey: .cardIndex) {
            cardIndex = indexAsString
        } else if let indexAsInt = try? dataContainer.decodeIfPresent(Int.self, forKey: .cardIndex) {
            cardIndex = String(indexAsInt)
        } else {
            cardIndex = nil
        }
        
        // Decode the card if present
        do {
            if var cardData = try dataContainer.decodeIfPresent(CardData.self, forKey: .card) {
                // We need to set the deckId on the card since it's not in the card data
                if let deckId = StudyService.shared.currentPlan?.deckId {
                    cardData.deckId = deckId
                }
                card = cardData
            } else {
                card = nil
            }
        } catch {
            card = nil
        }
        
        // Decode progress if present
        do {
            if let progressContainer = try? dataContainer.nestedContainer(keyedBy: ProgressCodingKeys.self, forKey: .progress) {
                let cardsReviewed = try progressContainer.decode(Int.self, forKey: .current)
                let totalCards = try progressContainer.decode(Int.self, forKey: .total)
                
                // Create SessionProgress with the values from the API
                progress = SessionProgress(
                    cardsReviewed: cardsReviewed,
                    totalCards: totalCards,
                    remainingCards: totalCards - cardsReviewed
                )
            } else {
                progress = nil
            }
        } catch {
            progress = nil
        }
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(message, forKey: .message)
        
        // We don't need to encode the nested structure for our internal use
    }
}

struct SessionResponseStats: Codable {
    let cardsReviewed: Int
    let correctResponses: Int
    let incorrectResponses: Int
    
    // Add CodingKeys to handle potential differences in API response
    enum CodingKeys: String, CodingKey {
        case cardsReviewed
        case correctResponses
        case incorrectResponses
        // Alternative keys
        case reviewed
        case correct
        case incorrect
        case cards_reviewed
        case correct_responses
        case incorrect_responses
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try different possible keys for cardsReviewed
        if let count = try container.decodeIfPresent(Int.self, forKey: .cardsReviewed) {
            cardsReviewed = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .reviewed) {
            cardsReviewed = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .cards_reviewed) {
            cardsReviewed = count
        } else {
            cardsReviewed = 0 // Default value
        }
        
        // Try different possible keys for correctResponses
        if let count = try container.decodeIfPresent(Int.self, forKey: .correctResponses) {
            correctResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .correct) {
            correctResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .correct_responses) {
            correctResponses = count
        } else {
            correctResponses = 0 // Default value
        }
        
        // Try different possible keys for incorrectResponses
        if let count = try container.decodeIfPresent(Int.self, forKey: .incorrectResponses) {
            incorrectResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .incorrect) {
            incorrectResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .incorrect_responses) {
            incorrectResponses = count
        } else {
            incorrectResponses = 0 // Default value
        }
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cardsReviewed, forKey: .cardsReviewed)
        try container.encode(correctResponses, forKey: .correctResponses)
        try container.encode(incorrectResponses, forKey: .incorrectResponses)
    }
}

struct AnswerResponse: Codable {
    let success: Bool
    let message: String?
    let stats: SessionResponseStats?
    
    // Add CodingKeys to handle potential differences in API response
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case stats
        // Alternative keys
        case status
        case error
        case data
        case sessionStats
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode success with a fallback to true if not present
        if let successValue = try container.decodeIfPresent(Bool.self, forKey: .success) {
            success = successValue
        } else if let statusValue = try container.decodeIfPresent(String.self, forKey: .status), statusValue == "success" {
            success = true
        } else {
            success = true // Default to true
        }
        
        // Try different possible keys for message
        let messageFromMessage = try? container.decodeIfPresent(String.self, forKey: .message)
        let messageFromError = try? container.decodeIfPresent(String.self, forKey: .error)
        message = messageFromMessage ?? messageFromError
        
        // Try different possible keys for stats
        if let statsData = try container.decodeIfPresent(SessionResponseStats.self, forKey: .stats) {
            stats = statsData
        } else if let statsData = try container.decodeIfPresent(SessionResponseStats.self, forKey: .data) {
            stats = statsData
        } else if let statsData = try container.decodeIfPresent(SessionResponseStats.self, forKey: .sessionStats) {
            stats = statsData
        } else {
            stats = nil
        }
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(stats, forKey: .stats)
    }
}

struct QualityStats: Codable {
    let quality0: Int
    let quality1: Int
    let quality2: Int
    let quality3: Int
    let quality0Percent: Double
    let quality1Percent: Double
    let quality2Percent: Double
    let quality3Percent: Double
    let averageQuality: Double
    
    enum CodingKeys: String, CodingKey {
        case quality0, quality1, quality2, quality3
        case quality0Percent, quality1Percent, quality2Percent, quality3Percent
        case averageQuality
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        quality0 = try container.decodeIfPresent(Int.self, forKey: .quality0) ?? 0
        quality1 = try container.decodeIfPresent(Int.self, forKey: .quality1) ?? 0
        quality2 = try container.decodeIfPresent(Int.self, forKey: .quality2) ?? 0
        quality3 = try container.decodeIfPresent(Int.self, forKey: .quality3) ?? 0
        
        quality0Percent = try container.decodeIfPresent(Double.self, forKey: .quality0Percent) ?? 0
        quality1Percent = try container.decodeIfPresent(Double.self, forKey: .quality1Percent) ?? 0
        quality2Percent = try container.decodeIfPresent(Double.self, forKey: .quality2Percent) ?? 0
        quality3Percent = try container.decodeIfPresent(Double.self, forKey: .quality3Percent) ?? 0
        
        averageQuality = try container.decodeIfPresent(Double.self, forKey: .averageQuality) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quality0, forKey: .quality0)
        try container.encode(quality1, forKey: .quality1)
        try container.encode(quality2, forKey: .quality2)
        try container.encode(quality3, forKey: .quality3)
        try container.encode(quality0Percent, forKey: .quality0Percent)
        try container.encode(quality1Percent, forKey: .quality1Percent)
        try container.encode(quality2Percent, forKey: .quality2Percent)
        try container.encode(quality3Percent, forKey: .quality3Percent)
        try container.encode(averageQuality, forKey: .averageQuality)
    }
}

struct SessionStats: Codable {
    let totalCards: Int
    let cardsReviewed: Int
    let correctResponses: Int
    let incorrectResponses: Int
    let accuracy: Double
    let averageResponseTime: Double?
    let duration: Double?
    let qualityStats: QualityStats?
    
    // Add CodingKeys to handle potential differences in API response
    enum CodingKeys: String, CodingKey {
        case totalCards
        case cardsReviewed
        case correctResponses
        case incorrectResponses
        case accuracy
        case averageResponseTime
        case duration
        case qualityStats
        // Alternative keys
        case total
        case reviewed
        case correct
        case incorrect
        case total_cards
        case cards_reviewed
        case correct_responses
        case incorrect_responses
        case avg_time
        case average_time
        case session_duration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try different possible keys for totalCards
        if let count = try container.decodeIfPresent(Int.self, forKey: .totalCards) {
            totalCards = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .total) {
            totalCards = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .total_cards) {
            totalCards = count
        } else {
            totalCards = 0 // Default value
        }
        
        // Try different possible keys for cardsReviewed
        if let count = try container.decodeIfPresent(Int.self, forKey: .cardsReviewed) {
            cardsReviewed = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .reviewed) {
            cardsReviewed = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .cards_reviewed) {
            cardsReviewed = count
        } else {
            cardsReviewed = 0 // Default value
        }
        
        // Try different possible keys for correctResponses
        if let count = try container.decodeIfPresent(Int.self, forKey: .correctResponses) {
            correctResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .correct) {
            correctResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .correct_responses) {
            correctResponses = count
        } else {
            correctResponses = 0 // Default value
        }
        
        // Try different possible keys for incorrectResponses
        if let count = try container.decodeIfPresent(Int.self, forKey: .incorrectResponses) {
            incorrectResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .incorrect) {
            incorrectResponses = count
        } else if let count = try container.decodeIfPresent(Int.self, forKey: .incorrect_responses) {
            incorrectResponses = count
        } else {
            incorrectResponses = 0 // Default value
        }
        
        // Calculate accuracy (if not provided)
        if let accuracyValue = try container.decodeIfPresent(Double.self, forKey: .accuracy) {
            accuracy = accuracyValue
        } else {
            // Calculate accuracy based on correct vs total reviewed
            if cardsReviewed > 0 {
                accuracy = Double(correctResponses) / Double(cardsReviewed)
            } else {
                accuracy = 0.0
            }
        }
        
        // Try different possible keys for averageResponseTime
        let avgTime1 = try? container.decodeIfPresent(Double.self, forKey: .averageResponseTime)
        let avgTime2 = try? container.decodeIfPresent(Double.self, forKey: .avg_time)
        let avgTime3 = try? container.decodeIfPresent(Double.self, forKey: .average_time)
        averageResponseTime = avgTime1 ?? avgTime2 ?? avgTime3 ?? nil
        
        // Try different possible keys for duration
        let dur1 = try? container.decodeIfPresent(Double.self, forKey: .duration)
        let dur2 = try? container.decodeIfPresent(Double.self, forKey: .session_duration)
        duration = dur1 ?? dur2 ?? nil
        
        // Try to decode quality stats
        qualityStats = try container.decodeIfPresent(QualityStats.self, forKey: .qualityStats)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalCards, forKey: .totalCards)
        try container.encode(cardsReviewed, forKey: .cardsReviewed)
        try container.encode(correctResponses, forKey: .correctResponses)
        try container.encode(incorrectResponses, forKey: .incorrectResponses)
        try container.encode(accuracy, forKey: .accuracy)
        try container.encodeIfPresent(averageResponseTime, forKey: .averageResponseTime)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(qualityStats, forKey: .qualityStats)
    }
}

struct SessionStatsResponse: Codable {
    let success: Bool
    let stats: SessionStats
    
    // Add CodingKeys to handle potential differences in API response
    enum CodingKeys: String, CodingKey {
        case success
        case stats
        // Alternative keys
        case status
        case data
        case sessionStats
    }
    
    enum DataCodingKeys: String, CodingKey {
        case sessionId, deckId, isActive, startTime, endTime
        case durationMinutes, totalCards, newCards, reviewCards
        case cardsReviewed, correctResponses, incorrectResponses
        case accuracy, qualityStats
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode success with a fallback to true if not present
        if let successValue = try container.decodeIfPresent(Bool.self, forKey: .success) {
            success = successValue
        } else if let statusValue = try container.decodeIfPresent(String.self, forKey: .status), statusValue == "success" {
            success = true
        } else {
            success = true // Default to true
        }
        
        // Try to decode stats directly
        if let statsData = try? container.decode(SessionStats.self, forKey: .stats) {
            stats = statsData
            return
        }
        
        // Try to decode from data object
        if let dataContainer = try? container.nestedContainer(keyedBy: DataCodingKeys.self, forKey: .data) {
            // Create a temporary dictionary to hold the decoded values
            var statsDict: [String: Any] = [:]
            
            // Decode basic stats
            if let totalCards = try? dataContainer.decode(Int.self, forKey: .totalCards) {
                statsDict["totalCards"] = totalCards
            }
            
            if let cardsReviewed = try? dataContainer.decode(Int.self, forKey: .cardsReviewed) {
                statsDict["cardsReviewed"] = cardsReviewed
            }
            
            if let correctResponses = try? dataContainer.decode(Int.self, forKey: .correctResponses) {
                statsDict["correctResponses"] = correctResponses
            }
            
            if let incorrectResponses = try? dataContainer.decode(Int.self, forKey: .incorrectResponses) {
                statsDict["incorrectResponses"] = incorrectResponses
            }
            
            if let accuracy = try? dataContainer.decode(Double.self, forKey: .accuracy) {
                statsDict["accuracy"] = accuracy
            }
            
            // Try to decode qualityStats as a nested object
            if let qualityStats = try? dataContainer.decode(QualityStats.self, forKey: .qualityStats) {
                // Re-encode to JSON and then decode as part of the full stats object
                let encoder = JSONEncoder()
                if let qualityData = try? encoder.encode(qualityStats),
                   let qualityDict = try? JSONSerialization.jsonObject(with: qualityData) as? [String: Any] {
                    statsDict["qualityStats"] = qualityDict
                }
            }
            
            // Convert dict to JSON
            if let jsonData = try? JSONSerialization.data(withJSONObject: statsDict) {
                do {
                    // Decode the stats from our reconstructed JSON
                    stats = try JSONDecoder().decode(SessionStats.self, from: jsonData)
                    return
                } catch {
                    print("Error decoding stats from reconstructed JSON: \(error)")
                }
            }
        }
        
        // Try other keys
        if let statsData = try? container.decode(SessionStats.self, forKey: .data) {
            stats = statsData
        } else if let statsData = try? container.decode(SessionStats.self, forKey: .sessionStats) {
            stats = statsData
        } else {
            throw DecodingError.valueNotFound(SessionStats.self, DecodingError.Context(
                codingPath: [CodingKeys.stats],
                debugDescription: "Stats not found in any expected field"
            ))
        }
    }
    
    // Add encode method to conform to Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(stats, forKey: .stats)
    }
}

// MARK: - Utility Types

// A type that can decode any JSON value
struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyDecodable cannot decode value"
            )
        }
    }
} 
