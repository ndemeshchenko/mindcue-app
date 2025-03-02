import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Binding var isPresented: Bool
    @Binding var isAuthenticated: Bool
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var authService = AuthService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("Sign in to continue your learning progress")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Email signin form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textContentType(.password)
                        
                        Button(action: handleEmailSignIn) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign In")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || !isValidForm)
                        
                        Button("Forgot Password?") {
                            // Handle forgot password
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
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
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValidForm: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        !password.isEmpty
    }
    
    private func handleEmailSignIn() {
        guard isValidForm else {
            errorMessage = "Please enter your email and password."
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                print("Starting sign in process in view")
                let token = try await authService.signIn(
                    email: email,
                    password: password
                )
                print("Sign in successful, token: \(token.prefix(10))...")
                
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

// Custom styles
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
} 