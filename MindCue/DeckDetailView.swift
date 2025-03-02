import SwiftUI

struct DeckDetailView: View {
    let deck: Deck
    @State private var showingStudySession = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    Text(deck.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(deck.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Tags section
                HStack(spacing: 12) {
                    TagView(text: deck.language.uppercased(), color: .blue)
                    TagView(text: deck.category, color: .purple)
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 16) {
//                    InfoRow(icon: "calendar", title: "Created", value: formatDate(deck.createdAt))
                    InfoRow(icon: "lock.open.fill", title: "Access", value: deck.isPublic ? "Public" : "Private")
                    InfoRow(icon: "gear", title: "Type", value: deck.isStatic ? "Static" : "Dynamic")
                }
                .padding(.vertical)
                
                Spacer()
                
                // Start Learning button
                Button(action: {
                    showingStudySession = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Learning")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $showingStudySession) {
            NavigationView {
                StudySessionView(deckId: deck.id, deckName: deck.name)
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
} 
