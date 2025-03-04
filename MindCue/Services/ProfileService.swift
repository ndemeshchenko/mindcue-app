import Foundation
import SwiftUI
import OSLog

class ProfileService: ObservableObject {
    static let shared = ProfileService()
    
    private let logger = Logger(subsystem: "com.mdem.MindCue", category: "ProfileService")
    private let baseURL = "https://d854-195-240-134-68.ngrok-free.app/api/user"
    private let authService = AuthService.shared
    
    @Published var userProfile: UserProfile?
    @Published var studyPlans: [StudyPlan] = []
    @Published var recentPlan: StudyPlan?
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchProfileData() async {
        guard let authHeaders = authService.getAuthorizationHeader() else {
            logger.error("Attempted to fetch profile without authentication")
            await MainActor.run {
                self.error = NSError(
                    domain: "com.mdem.MindCue",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "You must be signed in to view your profile"]
                )
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/profile") else {
                throw NSError(domain: "com.mdem.MindCue", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Add authentication header
            for (key, value) in authHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            logger.debug("Fetching profile data from \(url.absoluteString)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "com.mdem.MindCue", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            logger.debug("Profile API response status: \(httpResponse.statusCode)")
            
            // Check for authentication error
            if httpResponse.statusCode == 401 {
                logger.warning("Authentication failed when fetching profile")
                authService.signOut()
                throw NSError(domain: "com.mdem.MindCue", code: 401, userInfo: [NSLocalizedDescriptionKey: "Your session has expired. Please sign in again."])
            }
            
            // Check for other error status codes
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    logger.error("Profile API error: \(errorString)")
                }
                throw NSError(domain: "com.mdem.MindCue", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to load profile data"])
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            let profileResponse = try decoder.decode(ProfileResponse.self, from: data)
            
            // Update the published properties on the main thread
            await MainActor.run {
                self.userProfile = profileResponse.data.user
                self.studyPlans = profileResponse.data.studyPlans
                self.recentPlan = profileResponse.data.mostRecentPlan
                self.isLoading = false
                
                logger.info("Successfully loaded profile for user: \(profileResponse.data.user.username)")
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                logger.error("Failed to load profile: \(error.localizedDescription)")
            }
        }
    }
} 