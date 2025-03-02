import Foundation
import SwiftUI // This will ensure all project files are accessible

// Explicitly import the Models directory

// Import SignUpRequest

enum AuthError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    private let baseURL = "https://d854-195-240-134-68.ngrok-free.app/api/user/auth"
    private let tokenKey = "authToken"
    
    @Published var isAuthenticated = false
    @Published var authToken: String?
    
    init() {
        // Check for existing token on initialization
        if let savedToken = UserDefaults.standard.string(forKey: tokenKey) {
            self.authToken = savedToken
            self.isAuthenticated = true
            print("Found existing auth token, user is authenticated")
        } else {
            print("No auth token found, user is not authenticated")
        }
    }
    
    func signUp(username: String, email: String, password: String) async throws -> String {
        print("Starting signup process for \(email)")
        guard let url = URL(string: "\(baseURL)/register") else {
            print("Invalid URL: \(baseURL)/register")
            throw AuthError.invalidURL
        }
        
        let signUpRequest = SignUpRequest(
            username: username,
            email: email,
            password: password
        )
        
        print("Request payload: \(username), \(email), password length: \(password.count)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(signUpRequest)
            print("Request encoded successfully")
        } catch {
            print("Failed to encode request: \(error)")
            throw AuthError.networkError(error)
        }
        
        do {
            print("Sending request to \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Received response with \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                throw AuthError.invalidResponse
            }
            
            print("HTTP status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Error response: \(responseString)")
                }
                
                let errorResponse = try? JSONDecoder().decode(AuthResponse.self, from: data)
                let errorMessage = errorResponse?.message ?? "Unknown error"
                print("Error message: \(errorMessage)")
                throw AuthError.serverError(errorMessage)
            }
            
            print("Decoding successful response")
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let token = authResponse.token else {
                print("No token in response")
                throw AuthError.serverError("No token received")
            }
            
            print("Signup successful, token received")
            
            // Save token and update authentication state
            await MainActor.run {
                self.saveToken(token)
                self.isAuthenticated = true
                self.authToken = token
            }
            
            return token
        } catch {
            print("Network error: \(error)")
            throw AuthError.networkError(error)
        }
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        isAuthenticated = false
        authToken = nil
        print("User signed out")
    }
    
    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        print("Auth token saved to UserDefaults")
    }
    
    func getAuthorizationHeader() -> [String: String]? {
        if let token = authToken {
            return ["Authorization": "Bearer \(token)"]
        }
        return nil
    }
    
    func signIn(email: String, password: String) async throws -> String {
        print("Starting signin process for \(email)")
        guard let url = URL(string: "\(baseURL)/login") else {
            print("Invalid URL: \(baseURL)/login")
            throw AuthError.invalidURL
        }
        
        let signInRequest = [
            "email": email,
            "password": password
        ]
        
        print("Request payload: \(email), password length: \(password.count)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(signInRequest)
            print("Request encoded successfully")
        } catch {
            print("Failed to encode request: \(error)")
            throw AuthError.networkError(error)
        }
        
        do {
            print("Sending request to \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Received response with \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                throw AuthError.invalidResponse
            }
            
            print("HTTP status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Error response: \(responseString)")
                }
                
                let errorResponse = try? JSONDecoder().decode(AuthResponse.self, from: data)
                let errorMessage = errorResponse?.message ?? "Unknown error"
                print("Error message: \(errorMessage)")
                throw AuthError.serverError(errorMessage)
            }
            
            print("Decoding successful response")
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let token = authResponse.token else {
                print("No token in response")
                throw AuthError.serverError("No token received")
            }
            
            print("Signin successful, token received")
            
            // Save token and update authentication state
            await MainActor.run {
                self.saveToken(token)
                self.isAuthenticated = true
                self.authToken = token
            }
            
            return token
        } catch {
            print("Network error: \(error)")
            throw AuthError.networkError(error)
        }
    }
} 
