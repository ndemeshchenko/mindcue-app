import SwiftUI
import AuthenticationServices

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var isAuthenticated: Bool
    @Binding var showSignUp: Bool
    @Binding var showSignIn: Bool
    var signOut: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            // Menu content
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundStyle(.linearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        Text("MindCue")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal)
                    
                    // Menu items
                    if isAuthenticated {
                        MenuButton(icon: "person.fill", title: "Profile") {
                            // Handle profile action
                            withAnimation {
                                isShowing = false
                            }
                        }
                        MenuButton(icon: "gear", title: "Settings") {
                            // Handle settings action
                            withAnimation {
                                isShowing = false
                            }
                        }
                        MenuButton(icon: "arrow.right.square", title: "Sign Out") {
                            signOut()
                            withAnimation {
                                isShowing = false
                            }
                        }
                    } else {
                        MenuButton(icon: "person.fill.badge.plus", title: "Sign Up") {
                            showSignUp = true
                            withAnimation {
                                isShowing = false
                            }
                        }
                        MenuButton(icon: "person.fill", title: "Sign In") {
                            showSignIn = true
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 270)
                .background(
                    Color(.systemBackground)
                        .ignoresSafeArea()
                )
                .offset(x: isShowing ? 0 : -270)
                
                Spacer()
            }
        }
    }
}

struct MenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .foregroundColor(.primary)
    }
} 