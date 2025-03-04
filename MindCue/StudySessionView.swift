import SwiftUI

struct StudySessionView: View {
    let deckId: String
    let deckName: String
    
    @StateObject private var studyService = StudyService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEndSessionAlert = false
    @State private var showingSessionSummary = false
    @State private var sessionSummary: SessionSummary?
    @State private var showingAuthAlert = false
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Header with progress
                VStack(spacing: 4) {
                    Text(deckName)
                        .font(.headline)
                    
                    if let plan = studyService.currentPlan {
                        // Progress bar
                        ProgressView(value: Double(plan.cardsReviewed), total: Double(plan.totalCards))
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal)
                        
                        // Card counters - now showing new cards and review cards
                        HStack(spacing: 16) {
                            // New cards counter
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("New: \(plan.newCards)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Divider
                            Rectangle()
                                .frame(width: 1, height: 12)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            // Review cards counter
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Review: \(plan.reviewCards)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Divider
                            Rectangle()
                                .frame(width: 1, height: 12)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            // Total progress
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("\(plan.cardsReviewed)/\(plan.totalCards)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                
                if studyService.isLoading {
                    // Loading state
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Loading...")
                            .font(.headline)
                            .padding(.top)
                    }
                } else if studyService.authenticationFailed {
                    // Authentication failure state
                    VStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                            .padding()
                        
                        Text("Authentication Failed")
                            .font(.headline)
                        
                        Text("Your session has expired. Please sign in again.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Button("Sign In") {
                            // Dismiss this view and show sign in
                            presentationMode.wrappedValue.dismiss()
                            authService.signOut()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 5)
                    .padding()
                } else if let error = studyService.error {
                    // Error state
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text("Error")
                            .font(.headline)
                        
                        Text(error.localizedDescription)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Button("Try Again") {
                            Task {
                                await studyService.startStudySession(deckId: deckId)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 5)
                    .padding()
                } else if let plan = studyService.currentPlan, plan.isSessionComplete {
                    // Session complete state
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Session Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let stats = studyService.sessionStats {
                            VStack(spacing: 10) {
                                if let qualityStats = stats.qualityStats {
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text("Response Quality")
                                            .font(.headline)
                                            .padding(.bottom, 5)
                                        
                                        StatRow(
                                            icon: "exclamationmark.circle",
                                            title: "Again",
                                            value: "\(qualityStats.quality0) (\(Int(qualityStats.quality0Percent))%)",
                                            color: .red
                                        )
                                        
                                        StatRow(
                                            icon: "xmark.circle",
                                            title: "Hard",
                                            value: "\(qualityStats.quality1) (\(Int(qualityStats.quality1Percent))%)",
                                            color: .orange
                                        )
                                        
                                        StatRow(
                                            icon: "hand.thumbsdown",
                                            title: "Good",
                                            value: "\(qualityStats.quality2) (\(Int(qualityStats.quality2Percent))%)",
                                            color: .yellow
                                        )
                                        
                                        StatRow(
                                            icon: "hand.thumbsup",
                                            title: "Easy",
                                            value: "\(qualityStats.quality3) (\(Int(qualityStats.quality3Percent))%)",
                                            color: .green
                                        )
                                    }
                                } else {
                                    // Fallback to old stats if quality stats aren't available
                                    StatRow(
                                        icon: "checkmark.circle",
                                        title: "Correct",
                                        value: "\(stats.correctResponses)",
                                        color: .green
                                    )
                                    
                                    StatRow(
                                        icon: "xmark.circle",
                                        title: "Incorrect",
                                        value: "\(stats.incorrectResponses)",
                                        color: .red
                                    )
                                    
                                    StatRow(
                                        icon: "percent",
                                        title: "Accuracy",
                                        value: "\(Int(stats.accuracy * 100))%",
                                        color: .blue
                                    )
                                }
                                
                                if let avgTime = stats.averageResponseTime {
                                    StatRow(
                                        icon: "clock",
                                        title: "Avg. Response Time",
                                        value: String(format: "%.1f sec", avgTime),
                                        color: .purple
                                    )
                                }
                                
                                if let duration = stats.duration {
                                    StatRow(
                                        icon: "timer",
                                        title: "Total Duration",
                                        value: formatDuration(duration),
                                        color: .indigo
                                    )
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(15)
                        } else {
                            // Fallback to plan stats if API stats aren't available
                            VStack(spacing: 10) {
                                StatRow(
                                    icon: "checkmark.circle",
                                    title: "Correct",
                                    value: "\(plan.correctResponses)",
                                    color: .green
                                )
                                
                                StatRow(
                                    icon: "xmark.circle",
                                    title: "Incorrect",
                                    value: "\(plan.incorrectResponses)",
                                    color: .red
                                )
                                
                                if plan.cardsReviewed > 0 {
                                    StatRow(
                                        icon: "percent",
                                        title: "Accuracy",
                                        value: "\(Int(Double(plan.correctResponses) / Double(plan.cardsReviewed) * 100))%",
                                        color: .blue
                                    )
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(15)
                        }
                        
                        Button("Return to Deck") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 5)
                    .padding()
                } else if let card = studyService.currentCard {
                    // Current card view
                    StudyCardView(
                        card: card,
                        onResponse: { quality in
                            Task {
                                await studyService.recordResponse(quality: quality)
                            }
                        }
                    )
                } else if studyService.currentPlan != nil {
                    // No cards state
                    VStack {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("No cards to study")
                            .font(.headline)
                        
                        Text("All cards in this deck are up to date. Check back later!")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Button("Return to Deck") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 5)
                    .padding()
                } else {
                    // No plan state (should not happen, but just in case)
                    Text("No study session active")
                        .font(.headline)
                        .padding()
                }
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                if studyService.currentPlan != nil && !studyService.currentPlan!.isSessionComplete {
                    showingEndSessionAlert = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            },
            trailing: Button(action: {
                // Show help or settings
            }) {
                Image(systemName: "info.circle")
            }
        )
        .alert("End Session?", isPresented: $showingEndSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Session", role: .destructive) {
                if let plan = studyService.currentPlan {
                    sessionSummary = plan.sessionSummary
                }
                studyService.endStudySession()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your progress will be saved, but the session will end. Continue?")
        }
        .task {
            // Reset any previous authentication failure state
            studyService.resetAuthenticationFailure()
            
            // Start the study session when the view appears
            await studyService.startStudySession(deckId: deckId)
        }
        .onChange(of: studyService.authenticationFailed) { oldValue, newValue in
            if newValue {
                showingAuthAlert = true
            }
        }
        .alert("Authentication Failed", isPresented: $showingAuthAlert) {
            Button("Sign In Again") {
                presentationMode.wrappedValue.dismiss()
                authService.signOut()
            }
        } message: {
            Text("Your session has expired. Please sign in again to continue.")
        }
    }
    
    // Format duration in minutes and seconds
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

// Helper view for displaying statistics
struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal)
    }
} 