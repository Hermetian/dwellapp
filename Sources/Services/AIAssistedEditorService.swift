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
    case speedAdjustment(rate: Float)
    case transition(type: String)
}

public struct AIAssistedEditSuggestion {
    public let type: AIAssistedEditSuggestionType
    public let suggestionText: String
    public let confidence: Float
}

// AI Assisted Editor Service that integrates simulated LLM calls with our video functions.
public class AIAssistedEditorService {
    private let videoService: VideoService
    private let cloudService: GoogleCloudService
    
    public init(videoService: VideoService) throws {
        self.videoService = videoService
        self.cloudService = try GoogleCloudService()
    }
    
    // Analyzes video content (scene segmentation, transcript & quality issues)
    public func analyzeVideoContent(videoURL: URL) async throws -> AIVideoAnalysis {
        let analysisResult = try await cloudService.analyzeVideo(url: videoURL)
        return AIVideoAnalysis(
            scenes: analysisResult.scenes,
            transcript: analysisResult.transcript,
            qualityIssues: analysisResult.qualityIssues
        )
    }
    
    // Generates a list of recommended edits based on the analysis.
    public func generateEditingRecommendations(analysis: AIVideoAnalysis) async throws -> [AIAssistedEditSuggestion] {
        var suggestions = [AIAssistedEditSuggestion]()
        
        // Process quality issues
        if let issues = analysis.qualityIssues {
            for issue in issues {
                if issue.contains("scene changes") {
                    suggestions.append(AIAssistedEditSuggestion(
                        type: .speedAdjustment(rate: 0.8),
                        suggestionText: "Slow down video slightly to make scene changes less jarring",
                        confidence: 0.8
                    ))
                }
                
                if issue.contains("audio quality") {
                    // Suggest removing problematic audio segments or adding background music
                    if let scene = analysis.scenes.first(where: { $0.description.contains("low audio quality") }) {
                        suggestions.append(AIAssistedEditSuggestion(
                            type: .trim(start: scene.startTime, end: scene.endTime),
                            suggestionText: "Remove segment with poor audio quality",
                            confidence: 0.9
                        ))
                    }
                }
            }
        }
        
        // Analyze transcript sentiment if available
        if let transcript = analysis.transcript {
            let sentimentAnalysis = try await cloudService.analyzeContent(text: transcript)
            
            // If sentiment is very positive, suggest highlighting those moments
            if sentimentAnalysis.score > 0.8 {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .filter(.brightness(0.1)),
                    suggestionText: "Enhance positive moments with slightly brighter visuals",
                    confidence: 0.7
                ))
            }
        }
        
        // Process scenes for potential improvements
        for scene in analysis.scenes {
            if scene.description.contains("exterior") || scene.description.contains("landscape") {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .filter(.contrast(0.1)),
                    suggestionText: "Enhance exterior shots with subtle contrast boost",
                    confidence: 0.8
                ))
            }
            
            if scene.endTime - scene.startTime < CMTime(seconds: 2, preferredTimescale: 600) {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .speedAdjustment(rate: 0.8),
                    suggestionText: "Slow down quick scenes for better viewing",
                    confidence: 0.7
                ))
            }
        }
        
        return suggestions
    }
    
    // Interprets a high-level editing command and applies changes. For example, creating a highlight reel.
    public func applyEditingCommand(command: String, on videoURL: URL) async throws -> URL {
        if command.lowercased().contains("highlight reel") {
            let videoAnalysis = try await analyzeVideoContent(videoURL: videoURL)
            
            // Find the most interesting scenes based on description and duration
            let highlightScenes = videoAnalysis.scenes.filter { scene in
                let duration = scene.endTime - scene.startTime
                return duration.seconds >= 3 && duration.seconds <= 10 &&
                       !scene.description.isEmpty
            }.prefix(5)
            
            // Create video clips for each scene
            var clips: [VideoService.VideoClip] = []
            for scene in highlightScenes {
                let clip = VideoService.VideoClip(
                    sourceURL: videoURL,
                    startTime: scene.startTime,
                    duration: scene.endTime - scene.startTime
                )
                clips.append(clip)
            }
            
            return try await videoService.stitchClips(clips)
        }
        
        if command.lowercased().contains("enhance") {
            // Apply a combination of subtle enhancements
            var enhancedURL = videoURL
            
            if command.lowercased().contains("bright") {
                enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: .brightness(0.1))
            }
            
            if command.lowercased().contains("contrast") {
                enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: .contrast(0.1))
            }
            
            if command.lowercased().contains("color") {
                enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: .saturation(0.1))
            }
            
            return enhancedURL
        }
        
        // Default to returning original URL if command not recognized
        return videoURL
    }
    
    // Generates content suggestions (title, description, amenities) based on video content and property info.
    public func getContentSuggestions(for videoURL: URL, property: Property?) async throws -> (title: String, description: String, amenities: [String]) {
        let videoAnalysis = try await analyzeVideoContent(videoURL: videoURL)
        
        var titleComponents: [String] = []
        for scene in videoAnalysis.scenes where scene.description.contains("exterior") || scene.description.contains("interior") {
            titleComponents.append(scene.description)
        }
        
        if let transcript = videoAnalysis.transcript {
            let sentimentAnalysis = try await cloudService.analyzeContent(text: transcript)
            
            let title = titleComponents.isEmpty ? 
                "Stunning Property Tour" : 
                "Beautiful \(titleComponents.first ?? "Home") Showcase"
            
            let description = sentimentAnalysis.score > 0 ?
                "Experience this exceptional property featuring \(titleComponents.joined(separator: ", ").lowercased()). \(transcript.prefix(200))..." :
                "Discover this unique property with \(titleComponents.joined(separator: ", ").lowercased()). \(transcript.prefix(200))..."
            
            // Extract amenities from scene descriptions and transcript
            var amenities = Set<String>()
            for scene in videoAnalysis.scenes {
                if scene.description.contains("pool") { amenities.insert("Pool") }
                if scene.description.contains("gym") { amenities.insert("Gym") }
                if scene.description.contains("parking") { amenities.insert("Secure Parking") }
                if scene.description.contains("garden") { amenities.insert("Garden") }
            }
            
            // Add property-specific amenities if available
            if let propertyAmenities = property?.amenities {
                for (amenity, hasAmenity) in propertyAmenities {
                    if hasAmenity {
                        amenities.insert(amenity)
                    }
                }
            }
            
            return (title: title, description: description, amenities: Array(amenities))
        }
        
        // Fallback if no transcript available
        return (
            title: "Stunning Property Tour",
            description: "Explore this beautiful property featuring \(titleComponents.joined(separator: ", ").lowercased()).",
            amenities: ["Parking", "Modern Appliances"]
        )
    }
}
