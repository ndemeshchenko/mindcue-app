import Foundation
import SwiftUI

// This file ensures all auth components are accessible throughout the app

// Re-export AuthService
let authServiceShared = AuthService.shared

// Helper function for sign up
func signUpUser(username: String, email: String, password: String) async throws -> String {
    return try await AuthService.shared.signUp(username: username, email: email, password: password)
} 