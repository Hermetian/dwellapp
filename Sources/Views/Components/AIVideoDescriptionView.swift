import SwiftUI
import Core
import ViewModels

@MainActor
public struct AIVideoDescriptionView: View {
    let video: Video
    let suggestions: (title: String, description: String, amenities: [String])
    
    @State private var suggestedTitle: String
    @State private var suggestedDescription: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String = ""
    @State private var properties: [Property] = []
    @State private var bestMatchingProperty: Property?
    
    private let databaseService: DatabaseService
    private let authService: AuthService
    
    public init(video: Video, 
                suggestions: (title: String, description: String, amenities: [String]),
                databaseService: DatabaseService,
                authService: AuthService) {
        self.video = video
        self.suggestions = suggestions
        self.databaseService = databaseService
        self.authService = authService
        _suggestedTitle = State(initialValue: suggestions.title)
        _suggestedDescription = State(initialValue: suggestions.description)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("AI Video Description")
                    .font(.title)
                
                // Editable Suggested Title Section
                VStack(alignment: .leading) {
                    Text("Suggested Video Title")
                        .font(.headline)
                    TextField("Video Title", text: $suggestedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { saveTitle() }) {
                        Text("Save Title")
                    }
                }
                
                // Editable Suggested Description Section
                VStack(alignment: .leading) {
                    Text("Suggested Video Description")
                        .font(.headline)
                    TextEditor(text: $suggestedDescription)
                        .frame(height: 100)
                        .border(Color.gray, width: 1)
                    Button(action: { saveDescription() }) {
                        Text("Save Description")
                    }
                }
                
                // Properties Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attach Video to a Property")
                        .font(.headline)
                    if let bestProperty = bestMatchingProperty {
                        VStack(alignment: .leading) {
                            Text("Best Match: \(bestProperty.title)")
                                .font(.subheadline)
                            Text(bestProperty.description)
                                .font(.caption)
                            Button(action: { attachToProperty(property: bestProperty) }) {
                                Text("Attach to this Property")
                            }
                        }
                    } else {
                        if properties.isEmpty {
                            Text("Loading properties...")
                        } else {
                            Text("No matching property found.")
                        }
                    }
                }
                
                // Create New Property Section
                Button(action: { createNewProperty() }) {
                    Text("Create New Property from Video")
                }
                
                // Finalize Section
                Button(action: { finalizeVideoDescription() }) {
                    Text("Finalize Video Description")
                        .bold()
                }
                
                if isSaving {
                    ProgressView("Saving...")
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            fetchProperties()
        }
    }
    
    // Save suggested title
    func saveTitle() {
        guard let videoId = video.id else {
            errorMessage = "Video ID not found."
            return
        }
        isSaving = true
        
        Task {
            do {
                try await databaseService.updateVideo(id: videoId, data: ["suggestedTitle": suggestedTitle])
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = "Error saving title: \(error.localizedDescription)"
            }
        }
    }
    
    // Save suggested description
    func saveDescription() {
        guard let videoId = video.id else {
            errorMessage = "Video ID not found."
            return
        }
        isSaving = true
        
        Task {
            do {
                try await databaseService.updateVideo(id: videoId, data: ["suggestedDescription": suggestedDescription])
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = "Error saving description: \(error.localizedDescription)"
            }
        }
    }
    
    // Fetch current user's properties
    func fetchProperties() {
        Task {
            do {
                properties = try await databaseService.getProperties()
                computeBestMatchingProperty()
            } catch {
                errorMessage = "Error fetching properties: \(error.localizedDescription)"
            }
        }
    }
    
    // Compute the best matching property based on common words between its description and the suggested video description
    func computeBestMatchingProperty() {
        var bestScore = 0
        var bestProp: Property?
        let videoWords = Set(suggestedDescription.lowercased().split(separator: " ").map { String($0) })
        
        for property in properties {
            let propWords = Set(property.description.lowercased().split(separator: " ").map { String($0) })
            let common = videoWords.intersection(propWords)
            let score = common.count
            if score > bestScore {
                bestScore = score
                bestProp = property
            }
        }
        bestMatchingProperty = bestProp
    }
    
    // Attach the video to the given property
    func attachToProperty(property: Property) {
        guard let videoId = video.id else {
            errorMessage = "Video ID not found."
            return
        }
        isSaving = true
        
        Task {
            do {
                try await databaseService.updateVideo(id: videoId, data: [
                    "propertyId": property.id ?? "",
                    "isComplete": true
                ])
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = "Error attaching video: \(error.localizedDescription)"
            }
        }
    }
    
    // Create a new property pre-filled with the video's suggested title and description
    func createNewProperty() {
        guard let currentUserId = authService.currentUser?.id else {
            errorMessage = "User not logged in"
            return
        }
        
        let videoId = video.id ?? ""
        let newProperty = Property(
            id: nil,
            managerId: currentUserId,
            title: suggestedTitle,
            description: suggestedDescription,
            price: 0.0,
            address: "",
            videoIds: videoId.isEmpty ? [] : [videoId],
            thumbnailUrl: nil,
            bedrooms: 0,
            bathrooms: 0.0,
            squareFootage: 0.0,
            viewCount: 0,
            favoriteCount: 0,
            availableFrom: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            serverTimestamp: nil,
            amenities: [:],
            imageUrl: nil,
            type: "Property (Rent)",
            userId: currentUserId,
            isAvailable: true
        )
        
        isSaving = true
        Task {
            do {
                let propertyId = try await databaseService.createProperty(newProperty)
                
                if let videoId = video.id {
                    try await databaseService.updateVideo(id: videoId, data: [
                        "propertyId": propertyId,
                        "isComplete": true
                    ])
                }
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = "Error creating property: \(error.localizedDescription)"
            }
        }
    }
    
    // Finalize the video description
    func finalizeVideoDescription() {
        guard let videoId = video.id else {
            errorMessage = "Video ID not found."
            return
        }
        isSaving = true
        
        Task {
            do {
                try await databaseService.updateVideo(id: videoId, data: [
                    "finalTitle": suggestedTitle,
                    "finalDescription": suggestedDescription,
                    "isComplete": true
                ])
                isSaving = false
            } catch {
                isSaving = false
                errorMessage = "Error finalizing video description: \(error.localizedDescription)"
            }
        }
    }
}

struct AIVideoDescriptionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create dummy video with all required parameters
        let dummyVideo = Video(
            id: "test123",
            videoType: .property,
            propertyId: nil,
            title: "Test Video",
            description: "",
            videoUrl: "https://example.com/video.mp4",
            thumbnailUrl: nil,
            uploadDate: Date(),
            userId: "preview-user",
            serverTimestamp: nil,
            likeCount: 0,
            likedBy: []
        )
        
        let dummySuggestions = (
            title: "Beautiful Home Tour",
            description: "A stunning view of the home's interior and exterior, showcasing modern design.",
            amenities: ["Pool", "Gym"]
        )
        
        // Create preview with required services
        AIVideoDescriptionView(
            video: dummyVideo,
            suggestions: dummySuggestions,
            databaseService: DatabaseService(),
            authService: AuthService()
        )
    }
} 