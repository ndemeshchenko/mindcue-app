import SwiftUI
import AuthenticationServices
import Foundation

// Import AuthService
typealias MyAuthService = AuthService

struct SignUpView: View {
    // Add a static initializer to check if AuthService is accessible
    static let authServiceCheck: Bool = {
        print("AuthService shared instance exists: \(AuthService.shared)")
        return true
    }()
    
    @Binding var isPresented: Bool
    @Binding var isAuthenticated: Bool
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var authService = AuthService.shared
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("Join MindCue to start your language learning journey")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Email signup form
                    VStack(spacing: 16) {
                        TextField("Username", text: $username)
                            .textFieldStyle(.rounded)
                            .textContentType(.username)
                            .autocapitalization(.none)
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(.rounded)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.rounded)
                            .textContentType(.newPassword)
                        
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.rounded)
                            .textContentType(.newPassword)
                        
                        Button(action: handleEmailSignUp) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign Up with Email")
                            }
                        }
                        .buttonStyle(.primary)
                        .disabled(isLoading || !isValidForm)
                    }
                    .padding(.horizontal)
                    
                    // Divider
                    HStack {
                        VStack { Divider() }
                        Text("or")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        VStack { Divider() }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Sign in with Apple
                    SignInWithAppleButton { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignInWithApple(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
            .alert("Sign Up Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValidForm: Bool {
        let isValid = !username.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
        
        print("Form validation: Username empty? \(!username.isEmpty), Email valid? \(!email.isEmpty && email.contains("@")), Password valid? \(password.count >= 8), Passwords match? \(password == confirmPassword), Overall valid? \(isValid)")
        
        return isValid
    }
    
    private func testAuthService() {
        print("Testing AuthService...")
        let authService = AuthService.shared
        print("AuthService instance: \(authService)")
    }
    
    private func handleEmailSignUp() {
        print("Sign up button tapped!")
        
        guard isValidForm else {
            errorMessage = "Please check your input and try again."
            showError = true
            return
        }
        
        print("Form values - Username: \(username), Email: \(email), Password length: \(password.count), Confirm Password length: \(confirmPassword.count)")
        
        isLoading = true
        
        Task {
            do {
                print("Starting sign up process in view")
                let token = try await authService.signUp(
                    username: username,
                    email: email,
                    password: password
                )
                print("Sign up successful, token: \(token.prefix(10))...")
                
                // The token is already saved in AuthService
                await MainActor.run {
                    isAuthenticated = true
                    isPresented = false
                }
            } catch AuthError.serverError(let message) {
                print("Server error: \(message)")
                await MainActor.run {
                    errorMessage = message
                    showError = true
                }
            } catch AuthError.networkError(let error) {
                print("Network error: \(error)")
                await MainActor.run {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    showError = true
                }
            } catch AuthError.invalidURL {
                print("Invalid URL error")
                await MainActor.run {
                    errorMessage = "Invalid API URL. Please contact support."
                    showError = true
                }
            } catch AuthError.invalidResponse {
                print("Invalid response error")
                await MainActor.run {
                    errorMessage = "Received invalid response from server."
                    showError = true
                }
            } catch {
                print("Unexpected error: \(error)")
                await MainActor.run {
                    errorMessage = "Unexpected error: \(error.localizedDescription)"
                    showError = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Handle successful Apple sign in
                isAuthenticated = true
                isPresented = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
} 
