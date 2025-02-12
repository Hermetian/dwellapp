import SwiftUI
import Core
import ViewModels

public struct AIContentSuggestionView: View {
    @State private var suggestedTitle: String = ""
    @State private var suggestedDescription: String = ""
    @State private var suggestedAmenities: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    let videoURL: URL
    let property: Property?
    let aiService: AIAssistedEditorService
    
    public init(videoURL: URL, property: Property? = nil, videoService: VideoService) {
        self.videoURL = videoURL
        self.property = property
        self.aiService = AIAssistedEditorService(videoService: videoService)
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Generating suggestions...")
            } else if !suggestedTitle.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Title:")
                        .font(.headline)
                    TextField("Title", text: $suggestedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Suggested Description:")
                        .font(.headline)
                    TextField("Description", text: $suggestedDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Suggested Amenities:")
                        .font(.headline)
                    ForEach(suggestedAmenities, id: \.self) { amenity in
                        Text("• \(amenity)")
                    }
                }
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button("Get AI Suggestions") {
                Task {
                    await generateSuggestions()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func generateSuggestions() async {
        isLoading = true
        errorMessage = ""
        do {
            let suggestions = try await aiService.getContentSuggestions(for: videoURL, property: property)
            suggestedTitle = suggestions.title
            suggestedDescription = suggestions.description
            suggestedAmenities = suggestions.amenities
        } catch {
            errorMessage = "Failed to generate suggestions: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
