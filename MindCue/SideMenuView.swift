import SwiftUI
import AuthenticationServices

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var isAuthenticated: Bool
    @Binding var showSignUp: Bool
    @Binding var showSignIn: Bool
    @Binding var showProfile: Bool
    @EnvironmentObject var authService: AuthService
    @State private var showContent = false
    var signOut: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background only handles opacity transition
            Color.black.opacity(isShowing ? 0.3 : 0)
                .ignoresSafeArea()
                .animation(.easeIn(duration: 0.15), value: isShowing)
                .onTapGesture {
                    closeMenu()
                }
            
            // Menu content only handles sliding
            HStack(alignment: .top, spacing: 0) {
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
                        Button {
                            closeMenu()
                            
                            // Simple delay then show profile from parent
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showProfile = true
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "person.fill")
                                    .frame(width: 24)
                                Text("Profile")
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        
                        MenuButton(icon: "gear", title: "Settings") {
                            closeMenu()
                        }
                        
                        MenuButton(icon: "arrow.right.square", title: "Sign Out") {
                            signOut()
                            closeMenu()
                        }
                    } else {
                        MenuButton(icon: "person.fill.badge.plus", title: "Sign Up") {
                            closeMenu()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showSignUp = true
                            }
                        }
                        
                        MenuButton(icon: "person.fill", title: "Sign In") {
                            closeMenu()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showSignIn = true
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 270)
                .background(Color(.systemBackground))
                .offset(x: showContent ? 0 : -270)
                .animation(.easeOut(duration: 0.25).delay(0.1), value: showContent)
                
                Spacer()
            }
        }
        .onChange(of: isShowing) { newValue in
            if newValue {
                // First show the menu (with delay to let overlay fade in first)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            } else {
                // When closing, hide content first
                showContent = false
            }
        }
    }
    
    private func closeMenu() {
        showContent = false
        // Delay the isShowing update until after the menu slide animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation {
                isShowing = false
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
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
    }
} 