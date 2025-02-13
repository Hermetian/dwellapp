import SwiftUI
import AVKit
import Core
import ViewModels

public struct TestAIFeaturesView: View {
    @State private var videoURL: URL?
    @State private var isProcessing = false
    @State private var analysisResult: AIVideoAnalysis?
    @State private var suggestions: [AIAssistedEditSuggestion] = []
    @State private var contentSuggestions: (title: String, description: String, amenities: [String])?
    @State private var errorMessage: String?
    
    private let videoService = VideoService()
    private let aiService: AIAssistedEditorService?
    
    public init() {
        do {
            self.aiService = try AIAssistedEditorService(videoService: videoService)
        } catch {
            print("Failed to initialize AIAssistedEditorService: \(error)")
            self.aiService = nil
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let videoURL = videoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 300)
                }
                
                Button(action: {
                    Task {
                        await selectVideo()
                    }
                }) {
                    Text("Select Video")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                if isProcessing {
                    ProgressView("Processing video...")
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if aiService == nil {
                    Text("AI service is not available")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if let analysis = analysisResult {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Video Analysis Results:")
                            .font(.headline)
                        
                        Text("Scenes:")
                        ForEach(analysis.scenes, id: \.description) { scene in
                            Text("• \(scene.description) (\(String(format: "%.1f", scene.startTime.seconds))s - \(String(format: "%.1f", scene.endTime.seconds))s)")
                                .padding(.leading)
                        }
                        
                        if let transcript = analysis.transcript {
                            Text("Transcript:")
                                .font(.headline)
                            Text(transcript)
                                .padding(.leading)
                        }
                        
                        if let issues = analysis.qualityIssues {
                            Text("Quality Issues:")
                                .font(.headline)
                            ForEach(issues, id: \.self) { issue in
                                Text("• \(issue)")
                                    .padding(.leading)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Edit Suggestions:")
                            .font(.headline)
                        
                        ForEach(suggestions, id: \.suggestionText) { suggestion in
                            HStack {
                                Text("• \(suggestion.suggestionText)")
                                Spacer()
                                Text("\(Int(suggestion.confidence * 100))%")
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if let content = contentSuggestions {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Content Suggestions:")
                            .font(.headline)
                        
                        Text("Title:")
                            .fontWeight(.medium)
                        Text(content.title)
                            .padding(.leading)
                        
                        Text("Description:")
                            .fontWeight(.medium)
                        Text(content.description)
                            .padding(.leading)
                        
                        Text("Amenities:")
                            .fontWeight(.medium)
                        ForEach(content.amenities, id: \.self) { amenity in
                            Text("• \(amenity)")
                                .padding(.leading)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    private func selectVideo() async {
        // For testing, we'll use a sample video URL
        // In a real app, you'd use a proper video picker
        guard let testVideoURL = Bundle.main.url(forResource: "sample_property", withExtension: "mp4") else {
            errorMessage = "Test video not found"
            return
        }
        
        guard let aiService = aiService else {
            errorMessage = "AI service is not available"
            return
        }
        
        videoURL = testVideoURL
        isProcessing = true
        errorMessage = nil
        
        do {
            // First get the video analysis
            let analysis = try await aiService.analyzeVideoContent(videoURL: testVideoURL)
            analysisResult = analysis
            
            // Then run the dependent tasks concurrently
            async let suggestionsTask = aiService.generateEditingRecommendations(analysis: analysis)
            async let contentTask = aiService.getContentSuggestions(for: testVideoURL, property: nil)
            
            // Await the concurrent tasks
            let (suggestionResults, contentResults) = try await (suggestionsTask, contentTask)
            suggestions = suggestionResults
            contentSuggestions = contentResults
            
        } catch {
            errorMessage = "Error processing video: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
} 
