import Foundation
import OSLog

@MainActor
class DecksViewModel: ObservableObject {
    @Published var decks: [Deck] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let logger = Logger(subsystem: "com.mdem.MindCue", category: "DecksViewModel")
    private let authService = AuthService.shared
    
    func fetchDecks() async {
        isLoading = true
        error = nil
        
        do {
            guard let url = URL(string: "https://d854-195-240-134-68.ngrok-free.app/api/user/decks") else {
                logger.error("Invalid URL")
                throw URLError(.badURL)
            }
            
            logger.info("Fetching decks from: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Get the auth token from AuthService
            if let token = authService.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                logger.info("Using auth token from AuthService")
            } else {
                logger.warning("No auth token available, request may fail")
            }
            
            #if DEBUG
            // Print curl command for debugging
            let authHeader = authService.authToken != nil ? "-H 'Authorization: Bearer \(authService.authToken!)'" : ""
            let curl = """
            curl '\(url.absoluteString)' \
            -H 'Accept: application/json' \
            \(authHeader)
            """
            logger.debug("Equivalent curl command: \(curl)")
            #endif
            
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = httpResponse as? HTTPURLResponse {
                logger.info("HTTP Status Code: \(httpResponse.statusCode)")
                
                // If unauthorized, try to handle auth issues
                if httpResponse.statusCode == 401 {
                    logger.warning("Unauthorized request (401). Token may be invalid or expired.")
                    // You could implement token refresh logic here
                }
            }
            
            logger.info("Received data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            
            let decodedResponse = try JSONDecoder().decode(DecksResponse.self, from: data)
            self.decks = decodedResponse.data
            logger.info("Successfully decoded \(decodedResponse.count) decks")
        } catch {
            logger.error("Error fetching decks: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    logger.error("Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    logger.error("Type '\(type)' mismatch: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    logger.error("Value of type '\(type)' not found: \(context.debugDescription)")
                @unknown default:
                    logger.error("Unknown decoding error: \(decodingError)")
                }
            }
            self.error = error
        }
        
        isLoading = false
    }
} 
