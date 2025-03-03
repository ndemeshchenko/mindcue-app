import SwiftUI

struct StudyCardView: View {
    @ObservedObject var card: StudyCard
    @State private var isFlipped = false
    @State private var animationAmount = 0.0
    
    var onResponse: (Int) -> Void
    
    var body: some View {
        VStack {
            // Card content
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
                    .padding()
                
                // Front content (question)
                VStack(spacing: 20) {
                    Text("Question")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(card.front)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if let examples = card.examples, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Examples:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(examples, id: \.self) { example in
                                Text("• \(example)")
                                    .font(.body)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Add invisible spacer to maintain consistent height
                    if !isFlipped {
                        Spacer()
                            .frame(height: card.tags?.isEmpty ?? true ? 20 : 60)
                    }
                }
                .padding()
                .opacity(isFlipped ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: isFlipped)
                
                // Back content (answer)
                VStack(spacing: 20) {
                    Text("Answer")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(card.back)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if let tags = card.tags, !tags.isEmpty {
                        HStack {
                            ForEach(tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            if tags.count > 3 {
                                Text("+\(tags.count - 3)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .opacity(isFlipped ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isFlipped)
            }
            .onTapGesture {
                flipCard()
            }
            // Fixed height for card to ensure consistency
            .frame(minHeight: 350)
            
            // Response buttons container - always present but visibility changes
            VStack(spacing: 16) {
                Text("How well did you know this?")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Quality rating buttons
                HStack(spacing: 8) {
                    QualityButton(quality: 0, label: "Blackout", color: .red, action: handleResponse)
                    QualityButton(quality: 1, label: "Incorrect", color: .orange, action: handleResponse)
                    QualityButton(quality: 2, label: "Hard", color: .yellow, action: handleResponse)
                    QualityButton(quality: 3, label: "Perfect", color: .green, action: handleResponse)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
            .opacity(isFlipped ? 1 : 0)
            .animation(.easeInOut, value: isFlipped)
        }
    }
    
    // Handle response with quality rating
    private func handleResponse(quality: Int) {
        card.hasBeenReviewed = true
        card.lastResponseQuality = quality
        onResponse(quality)
        resetCard()
    }
    
    // Flip the card with animation
    private func flipCard() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped.toggle()
        }
    }
    
    // Reset the card to front side for the next card
    private func resetCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.0)) {
                isFlipped = false
            }
        }
    }
}

// Quality rating button
struct QualityButton: View {
    let quality: Int
    let label: String
    let color: Color
    let action: (Int) -> Void
    
    var body: some View {
        Button(action: {
            action(quality)
        }) {
            VStack(spacing: 4) {
                Text("\(quality)")
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
} 