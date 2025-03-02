import SwiftUI

struct DecksView: View {
    @StateObject private var viewModel = DecksViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error loading decks")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                List(viewModel.decks) { deck in
                    NavigationLink(destination: DeckDetailView(deck: deck)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(deck.name)
                                .font(.headline)
                            Text(deck.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(deck.language.uppercased())
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .clipShape(Capsule())
                                
                                Text(deck.category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Browse Decks")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.fetchDecks()
        }
    }
} 