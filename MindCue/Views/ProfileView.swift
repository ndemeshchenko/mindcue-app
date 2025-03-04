import SwiftUI

struct ProfileView: View {
    @StateObject private var profileService = ProfileService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if profileService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding(.top, 40)
                    } else if let error = profileService.error {
                        ErrorView(error: error, retryAction: loadProfile)
                    } else if let profile = profileService.userProfile {
                        // Profile header
                        ProfileHeaderView(profile: profile)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Recent activity
                        if let recentPlan = profileService.recentPlan {
                            RecentActivityView(plan: recentPlan)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Study plans
                        StudyPlansView(plans: profileService.studyPlans)
                        
                        // Account actions
                        AccountActionsView(signOutAction: signOut)
                    } else {
                        Text("No profile data available")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await profileService.fetchProfileData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        Task {
            await profileService.fetchProfileData()
        }
    }
    
    private func signOut() {
        authService.signOut()
        dismiss()
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    let profile: UserProfile
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                
                Text(String(profile.username.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
            
            // Username
            Text(profile.username)
                .font(.title)
                .fontWeight(.bold)
            
            // Email
            Text(profile.email)
                .foregroundColor(.secondary)
            
            // Account Type & Join Date
            HStack(spacing: 16) {
                Label {
                    Text(profile.role.capitalized)
                        .font(.caption)
                } icon: {
                    Image(systemName: "person.badge.shield.checkmark")
                        .foregroundColor(.blue)
                }
                
                Label {
                    Text("Joined \(profile.formattedJoinDate)")
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Recent Activity View
struct RecentActivityView: View {
    let plan: StudyPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(alignment: .top) {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.deckName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let settings = plan.settings {
                        Text("Learning \(settings.newCardsPerDay) new cards per day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Last studied: \(plan.formattedCreationDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                // Navigate to this deck
            }) {
                Text("Continue Studying")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Study Plans View
struct StudyPlansView: View {
    let plans: [StudyPlan]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Study Plans")
                .font(.headline)
                .padding(.bottom, 4)
            
            if plans.isEmpty {
                Text("You haven't created any study plans yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(plans) { plan in
                    HStack {
                        Circle()
                            .fill(plan.isActive ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        
                        Text(plan.deckName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if let settings = plan.settings {
                            Text("\(settings.newCardsPerDay) cards/day")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Account Actions View
struct AccountActionsView: View {
    let signOutAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: signOutAction) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    
                    Text("Sign Out")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Profile")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthService.shared)
    }
} 