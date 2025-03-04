//
//  ContentView.swift
//  MindCue
//
//  Created by Mykyta Demeshchenko on 28/02/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var profileService = ProfileService.shared
    @State private var isSideMenuShowing = false
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var showProfile = false
    @State private var showStudySession = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App logo and title
                    VStack(spacing: 15) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .foregroundStyle(.linearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        
                        Text("MindCue")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Text("Master Languages Through Flash Cards")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Quick stats
                    HStack(spacing: 40) {
                        StatView(icon: "book.fill", title: "12", subtitle: "Languages")
                        StatView(icon: "star.fill", title: "1000+", subtitle: "Words")
                    }
                    
                    // Action buttons
                    VStack(spacing: 15) {
                        Button(action: {
                            if !authService.isAuthenticated {
                                showSignIn = true
                            } else if let recentPlan = profileService.recentPlan {
                                // Continue with existing study plan
                                showStudySession = true
                            } else {
                                // Navigate to decks to start learning
                                // (This would typically navigate to deck selection)
                            }
                        }) {
                            HStack {
                                Image(systemName: authService.isAuthenticated && profileService.recentPlan != nil ? "arrow.right.circle.fill" : "play.fill")
                                Text(authService.isAuthenticated && profileService.recentPlan != nil ? "Continue Studying" : "Start Learning")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        
                        NavigationLink(destination: DecksView()) {
                            HStack {
                                Image(systemName: "square.stack.fill")
                                Text("Browse Decks")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                
                // Add this at the end of the ZStack
                SideMenuView(
                    isShowing: $isSideMenuShowing,
                    isAuthenticated: $authService.isAuthenticated,
                    showSignUp: $showSignUp,
                    showSignIn: $showSignIn,
                    showProfile: $showProfile,
                    signOut: authService.signOut
                )
                .environmentObject(authService)
            }
            .navigationBarItems(leading: Button(action: {
                // Just toggle the flag, the SideMenuView will handle the animations
                isSideMenuShowing.toggle()
            }) {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.primary)
            })
            .sheet(isPresented: $showSignUp) {
                SignUpView(
                    isPresented: $showSignUp,
                    isAuthenticated: $authService.isAuthenticated
                )
            }
            .sheet(isPresented: $showSignIn) {
                SignInView(
                    isPresented: $showSignIn,
                    isAuthenticated: $authService.isAuthenticated
                )
            }
            .fullScreenCover(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authService)
            }
            .fullScreenCover(isPresented: $showStudySession) {
                if let recentPlan = profileService.recentPlan {
                    NavigationView {
                        StudySessionView(deckId: recentPlan.deckId._id, deckName: recentPlan.deckName)
                    }
                }
            }
            .onAppear {
                print("ContentView appeared, authentication state: \(authService.isAuthenticated)")
                if authService.isAuthenticated {
                    // Fetch profile data to get study plans
                    Task {
                        await profileService.fetchProfileData()
                    }
                }
            }
        }
    }
}

struct StatView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

#Preview {
    ContentView()
}
