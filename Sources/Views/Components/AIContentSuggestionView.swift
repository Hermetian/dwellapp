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
    let aiService: AIAssistedEditorService?
    
    public init(videoURL: URL, property: Property? = nil, videoService: VideoService) {
        self.videoURL = videoURL
        self.property = property
        do {
            self.aiService = try AIAssistedEditorService(videoService: videoService)
        } catch {
            print("Failed to initialize AIAssistedEditorService: \(error)")
            self.aiService = nil
            self.errorMessage = "AI service initialization failed: \(error.localizedDescription)"
        }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if aiService == nil {
                Text("AI service is not available")
                    .foregroundColor(.red)
            } else {
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
                
                Button("Get AI Suggestions") {
                    Task {
                        await generateSuggestions()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private func generateSuggestions() async {
        guard let aiService = aiService else {
            errorMessage = "AI service is not available"
            return
        }
        
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
