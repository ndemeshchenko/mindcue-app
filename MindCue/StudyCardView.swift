import SwiftUI

struct StudyCardView: View {
    @ObservedObject var card: StudyCard
    @State private var isFlipped = false
    @State private var cardRotation = 0.0
    @State private var contentRotation = 0.0
    
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
                    .rotation3DEffect(
                        .degrees(cardRotation),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                
                // Front content (question)
                if !isFlipped {
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
                    }
                    .padding()
                    .rotation3DEffect(
                        .degrees(contentRotation),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                }
                
                // Back content (answer)
                if isFlipped {
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
                    .rotation3DEffect(
                        .degrees(contentRotation),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                }
            }
            .onTapGesture {
                flipCard()
            }
            
            // Response buttons (only visible when card is flipped)
            if isFlipped {
                VStack(spacing: 16) {
                    Text("How well did you know this?")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Quality rating buttons
                    HStack(spacing: 8) {
                        QualityButton(quality: 0, label: "No idea", color: .red, action: handleResponse)
                        QualityButton(quality: 1, label: "Wrong", color: .orange, action: handleResponse)
                        QualityButton(quality: 2, label: "Hard", color: .yellow, action: handleResponse)
                        QualityButton(quality: 3, label: "Good", color: .green, action: handleResponse)
                        QualityButton(quality: 4, label: "Easy", color: .blue, action: handleResponse)
                        QualityButton(quality: 5, label: "Perfect", color: .purple, action: handleResponse)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                .transition(.opacity)
                .animation(.easeInOut, value: isFlipped)
            }
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
        let duration = 0.5
        withAnimation(.easeInOut(duration: duration)) {
            cardRotation += 180
        }
        
        // Rotate content halfway through the card flip
        DispatchQueue.main.asyncAfter(deadline: .now() + (duration / 2)) {
            contentRotation += 180
            isFlipped.toggle()
        }
    }
    
    // Reset the card to front side for the next card
    private func resetCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.0)) {
                isFlipped = false
                cardRotation = 0
                contentRotation = 0
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