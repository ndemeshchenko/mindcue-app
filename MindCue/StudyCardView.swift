import SwiftUI

struct StudyCardView: View {
    @ObservedObject var card: StudyCard
    @State private var isFlipped = false
    @State private var rotation: Double = 0
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    
    var onResponse: (Int) -> Void
    
    var body: some View {
        VStack {
            // Card content
            ZStack {
                // Card background with 3D rotation
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
                    .padding()
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                
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
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .opacity(rotation < 90 ? 1 : 0) // Only visible when rotation is less than 90 degrees
                
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
                .rotation3DEffect(
                    .degrees(rotation - 180),  // Offset by 180 degrees to appear on back
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .opacity(rotation >= 90 ? 1 : 0) // Only visible when rotation is 90 degrees or more
            }
            .onTapGesture {
                flipCard()
            }
            // Fixed height for card to ensure consistency
            .frame(minHeight: 350)
            .offset(x: offset)
            .opacity(opacity)
            
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
        
        // Perform swipe animation
        let direction: CGFloat = quality > 1 ? 1 : -1 // Swipe right for good, left for poor
        let swipeDistance: CGFloat = UIScreen.main.bounds.width * 1.5 * direction
        
        withAnimation(.easeOut(duration: 0.4)) {
            offset = swipeDistance
            opacity = 0
        }
        
        // Wait for animation to complete, then call onResponse and reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onResponse(quality)
            resetCard()
        }
    }
    
    // Flip the card with 3D animation
    private func flipCard() {
        let animationDuration = 0.5
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            // Animate to 180 degrees for a full flip
            rotation = isFlipped ? 0 : 180
            
            // Update isFlipped state mid-way through the animation
            DispatchQueue.main.asyncAfter(deadline: .now() + (animationDuration / 2)) {
                isFlipped.toggle()
            }
        }
    }
    
    // Reset the card to front side for the next card
    private func resetCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.none) {
                isFlipped = false
                rotation = 0
                offset = 0
                opacity = 0 // Start invisible for the new card
            }
            
            // Fade in the new card
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                opacity = 1
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