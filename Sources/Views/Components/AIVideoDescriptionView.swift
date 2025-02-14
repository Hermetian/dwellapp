import SwiftUI
import Core
import ViewModels

public struct AIVideoDescriptionView: View {
    let video: Video
    let suggestions: (title: String, description: String, amenities: [String])
    @State private var showCreateProperty = false
    @Environment(\.dismiss) private var dismiss
    
    public init(video: Video, suggestions: (title: String, description: String, amenities: [String])) {
        self.video = video
        self.suggestions = suggestions
    }
    
    private var suggestionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested Title")
                .font(.headline)
            Text(suggestions.title)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Text("Suggested Description")
                .font(.headline)
            Text(suggestions.description)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            if !suggestions.amenities.isEmpty {
                Text("Detected Amenities")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(suggestions.amenities, id: \.self) { amenity in
                        Text(amenity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    suggestionsContent
                    
                    Button {
                        showCreateProperty = true
                    } label: {
                        Text("Create Property with These Details")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                    .disabled(video.id == nil)
                }
            }
            .navigationTitle("AI Generated Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateProperty) {
                PropertyEditSheet(
                    property: .constant(Property(
                        managerId: "",
                        title: suggestions.title,
                        description: suggestions.description,
                        price: 0,
                        address: "",
                        videoIds: [video.id ?? ""],
                        bedrooms: 1,
                        bathrooms: 1,
                        squareFootage: 0,
                        availableFrom: Date(),
                        type: PropertyTypes.propertyRent.rawValue,
                        userId: ""
                    )),
                    editingVideos: .constant([])
                )
            }
        }
    }
} 