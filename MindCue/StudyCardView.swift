import SwiftUI

struct StudyCardView: View {
    @ObservedObject var card: StudyCard
    @State private var isFlipped = false
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var hasBeenFlippedOnce = false // Track if card has ever been flipped
    @State private var buttonsOpacity: Double = 1 // Separate opacity for buttons
    
    var onResponse: (Int) -> Void
    
    var body: some View {
        VStack {
            // Card with 3D flip effect
            ZStack {
                // Front card (Question)
                CardFace(
                    title: "Question",
                    content: card.front,
                    examples: (card.examples?.count ?? 0) > 0 ? [card.examples![0]] : nil, // Only Dutch example
                    tags: nil,
                    isFlipped: isFlipped,
                    isFrontFace: true,
                    partOfSpeech: card.partOfSpeech // Use actual partOfSpeech property
                )
                
                // Back card (Answer)
                CardFace(
                    title: "Answer",
                    content: card.back,
                    examples: (card.examples?.count ?? 0) > 1 ? [card.examples![1]] : nil, // Only English example
                    tags: nil,
                    isFlipped: isFlipped,
                    isFrontFace: false,
                    partOfSpeech: nil // No need to show Part of Speech on answer side
                )
            }
            .frame(minHeight: 350)
            .onTapGesture {
                flipCard()
            }
            .offset(x: offset)
            .opacity(opacity)
            
            // Response buttons container - always present once revealed
            VStack(spacing: 16) {
                Text("How well did you know this?")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Quality rating buttons
                HStack(spacing: 8) {
                    QualityButton(quality: 0, label: "Again", color: .red, action: handleResponse)
                    QualityButton(quality: 1, label: "Hard", color: .orange, action: handleResponse)
                    QualityButton(quality: 2, label: "Good", color: .yellow, action: handleResponse)
                    QualityButton(quality: 3, label: "Easy", color: .green, action: handleResponse)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
            .opacity(hasBeenFlippedOnce ? buttonsOpacity : 0) // Show buttons once card has been flipped at least once
            .animation(.easeInOut, value: hasBeenFlippedOnce)
        }
        .onAppear {
            // Ensure card starts in non-flipped state when it appears
            isFlipped = false
            hasBeenFlippedOnce = false
            buttonsOpacity = 1
        }
    }
    
    // Handle response with quality rating
    private func handleResponse(quality: Int) {
        card.hasBeenReviewed = true
        card.lastResponseQuality = quality
        
        // Perform swipe animation
        let direction: CGFloat = quality > 1 ? 1 : -1 // Swipe right for good, left for poor
        let swipeDistance: CGFloat = UIScreen.main.bounds.width * 1.5 * direction
        
        // Animate card swipe and buttons fade out simultaneously
        withAnimation(.easeOut(duration: 0.4)) {
            offset = swipeDistance
            opacity = 0
            buttonsOpacity = 0 // Fade out buttons at the same time
        }
        
        // Wait for animation to complete, then call onResponse and reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onResponse(quality)
            resetCard()
        }
    }
    
    // Flip the card with 3D animation
    private func flipCard() {
        // Check if this is the first flip from question to answer
        let isFirstFlipToAnswer = !isFlipped && !hasBeenFlippedOnce
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isFlipped.toggle()
            
            // Set hasBeenFlippedOnce to true if this is the first flip to answer
            if isFirstFlipToAnswer {
                hasBeenFlippedOnce = true
            }
        }
    }
    
    // Reset the card to front side for the next card
    private func resetCard() {
        // First make card invisible
        withAnimation(.none) {
            isFlipped = false
            hasBeenFlippedOnce = false
            offset = 0
            opacity = 0
            buttonsOpacity = 1 // Reset button opacity for next card
        }
        
        // Ensure we're fully reset for the next card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then fade in the new card (in question state)
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
        }
    }
}

// A single face of the card (front or back)
struct CardFace: View {
    let title: String
    let content: String
    let examples: [String]?
    let tags: [String]?
    let isFlipped: Bool
    let isFrontFace: Bool
    let partOfSpeech: String?
    
    var body: some View {
        // Only show the content when this face should be visible
        // (front face when not flipped, back face when flipped)
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
                .padding()
            
            // Card content
            VStack(spacing: 20) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Content area with standardized height and padding
                VStack {
                    if isFrontFace {
                        // Word in blue with part of speech for question side
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(content)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                            
                            // Display part of speech if available
                            if let pos = partOfSpeech {
                                Text(pos)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        // Regular display for answer side
                        Text(content)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 60) // Fixed height for content area
                .padding(.horizontal)
                
                // Examples area with standardized position
                VStack {
                    if let examples = examples, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Examples:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(examples, id: \.self) { example in
                                Text(example)
                                    .font(.body)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Empty space holder when no examples
                        Spacer().frame(height: 0)
                    }
                }
                .frame(minHeight: 60) // Minimum height for examples area
                
                if let tags = tags, !tags.isEmpty {
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
                
                // Add spacer to maintain consistent height
                Spacer()
            }
            .padding()
        }
        // Apply 3D rotation
        .rotation3DEffect(
            .degrees(isFlipped ? (isFrontFace ? 180 : 0) : (isFrontFace ? 0 : -180)),
            axis: (x: 0, y: 1, z: 0)
        )
        // This is key: hide the backside when it's facing away from the viewer
        .opacity(isFlipped == isFrontFace ? 0 : 1)
        // Prevent interaction with the face that's not visible
        .allowsHitTesting(isFlipped == !isFrontFace)
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