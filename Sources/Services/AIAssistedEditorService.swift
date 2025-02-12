import Foundation
import AVFoundation
import CoreImage
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#endif

// Data models used by the assistant
public struct Scene: Codable {
    public let startTime: CMTime
    public let endTime: CMTime
    public let description: String
    
    enum CodingKeys: String, CodingKey {
        case startTime
        case endTime
        case description
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startSeconds = try container.decode(Double.self, forKey: .startTime)
        let endSeconds = try container.decode(Double.self, forKey: .endTime)
        description = try container.decode(String.self, forKey: .description)
        
        startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        endTime = CMTime(seconds: endSeconds, preferredTimescale: 600)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startTime.seconds, forKey: .startTime)
        try container.encode(endTime.seconds, forKey: .endTime)
        try container.encode(description, forKey: .description)
    }
    
    public init(startTime: CMTime, endTime: CMTime, description: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.description = description
    }
}

public struct AIVideoAnalysis {
    public let scenes: [Scene]
    public let transcript: String?
    public let qualityIssues: [String]?
}

public enum AIAssistedEditSuggestionType {
    case trim(start: CMTime, end: CMTime)
    case filter(VideoService.VideoFilter)
    case addTitleSlide(title: String)
    // Extend with other suggestion types as needed
}

public struct AIAssistedEditSuggestion {
    public let type: AIAssistedEditSuggestionType
    public let suggestionText: String
}

// AI Assisted Editor Service that integrates simulated LLM calls with our video functions.
public class AIAssistedEditorService {
    private let videoService: VideoService
    
    public init(videoService: VideoService) {
        self.videoService = videoService
    }
    
    // Analyzes video content (scene segmentation, transcript & quality issues)
    public func analyzeVideoContent(videoURL: URL) async throws -> AIVideoAnalysis {
        // In production, call a video analysis API and a speech-to-text service
        let dummyScene = Scene(
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            endTime: CMTime(seconds: 10, preferredTimescale: 600),
            description: "Opening scene with a wide view of the property"
        )
        let transcript = "Welcome to this beautiful property located in..."
        let qualityIssues = ["Slight camera shake detected around 0:45-0:50"]
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulated delay
        return AIVideoAnalysis(scenes: [dummyScene], transcript: transcript, qualityIssues: qualityIssues)
    }
    
    // Generates a list of recommended edits based on the analysis.
    public func generateEditingRecommendations(analysis: AIVideoAnalysis) async throws -> [AIAssistedEditSuggestion] {
        var suggestions = [AIAssistedEditSuggestion]()
        
        if let qualityIssues = analysis.qualityIssues, !qualityIssues.isEmpty {
            let trimSuggestion = AIAssistedEditSuggestion(
                type: .trim(start: CMTime(seconds: 45, preferredTimescale: 600),
                            end: CMTime(seconds: 50, preferredTimescale: 600)),
                suggestionText: qualityIssues.first ?? "Trim the shaky segment between 0:45 and 0:50."
            )
            suggestions.append(trimSuggestion)
        }
        
        let filterSuggestion = AIAssistedEditSuggestion(
            type: .filter(.brightness(0.1)),
            suggestionText: "Slightly increase brightness to enhance visuals."
        )
        suggestions.append(filterSuggestion)
        
        if let transcript = analysis.transcript, transcript.contains("Welcome") {
            let titleSlideSuggestion = AIAssistedEditSuggestion(
                type: .addTitleSlide(title: "Welcome to Your Dream Home"),
                suggestionText: "Add a title slide with a catchy property name."
            )
            suggestions.append(titleSlideSuggestion)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        return suggestions
    }
    
    // Interprets a high-level editing command and applies changes. For example, creating a highlight reel.
    public func applyEditingCommand(command: String, on videoURL: URL) async throws -> URL {
        if command.lowercased().contains("highlight reel") {
            let asset = AVAsset(url: videoURL)
            let duration = try await asset.load(.duration)
            let newDuration = min(duration.seconds, 60)
            let highlightURL = try await videoService.trimVideo(url: videoURL, startTime: .zero, endTime: CMTime(seconds: newDuration, preferredTimescale: 600))
            return highlightURL
        }
        return videoURL
    }
    
    // Generates content suggestions (title, description, amenities) based on video content and property info.
    public func getContentSuggestions(for videoURL: URL, property: Property?) async throws -> (title: String, description: String, amenities: [String]) {
        try await Task.sleep(nanoseconds: 500_000_000)
        let suggestedTitle = property?.title ?? "Stunning Property Tour"
        let suggestedDescription = property != nil ?
            "Explore the unique features of this property, from its spacious living area to modern amenities." :
            "Watch this captivating video tour showcasing a beautiful space with great design."
        let suggestedAmenities = ["Pool", "Gym", "Secure Parking", "High-Speed Internet"]
        return (title: suggestedTitle, description: suggestedDescription, amenities: suggestedAmenities)
    }
}
