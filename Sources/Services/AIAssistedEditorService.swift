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

        // Process quality issues using advanced heuristics
        if let issues = analysis.qualityIssues, !issues.isEmpty {
            for issue in issues {
                if issue.lowercased().contains("scene change") {
                    let speedAdjustment: Float = issue.components(separatedBy: ",").count > 1 ? 0.75 : 0.85
                    suggestions.append(AIAssistedEditSuggestion(
                        type: .speedAdjustment(rate: speedAdjustment),
                        suggestionText: "Adjust video speed to smooth out rapid scene changes",
                        confidence: 0.8
                    ))
                }
                
                if issue.lowercased().contains("audio") {
                    if let scene = analysis.scenes.first(where: { $0.description.lowercased().contains("poor audio") || $0.description.lowercased().contains("low audio") }) {
                        suggestions.append(AIAssistedEditSuggestion(
                            type: .trim(start: scene.startTime, end: scene.endTime),
                            suggestionText: "Trim segment with poor audio quality for better overall sound",
                            confidence: 0.9
                        ))
                    }
                }
            }
        }

        // Analyze transcript sentiment using actual sentiment score
        if let transcript = analysis.transcript, !transcript.isEmpty {
            let sentimentAnalysis = try await cloudService.analyzeContent(text: transcript)
            if sentimentAnalysis.score >= 0.8 {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .filter(.brightness(0.1)),
                    suggestionText: "Boost brightness to accentuate positive moments",
                    confidence: 0.75
                ))
            } else if sentimentAnalysis.score <= 0.2 {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .filter(.contrast(0.1)),
                    suggestionText: "Enhance contrast to emphasize dramatic moments",
                    confidence: 0.75
                ))
            }
        }

        // Process scenes with advanced duration logic
        for scene in analysis.scenes {
            let durationSeconds = scene.endTime.seconds - scene.startTime.seconds
            if scene.description.lowercased().contains("exterior") || scene.description.lowercased().contains("landscape") {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .filter(.contrast(0.1)),
                    suggestionText: "Increase contrast to bring out exterior scene details",
                    confidence: 0.8
                ))
            }
            
            if durationSeconds < 2.0 {
                suggestions.append(AIAssistedEditSuggestion(
                    type: .speedAdjustment(rate: 0.8),
                    suggestionText: "Slow down the brief scene for better visibility",
                    confidence: 0.7
                ))
            }
        }

        // Fallback suggestion if no recommendations were generated
        if suggestions.isEmpty {
            suggestions.append(AIAssistedEditSuggestion(
                type: .filter(.saturation(0.1)),
                suggestionText: "Apply subtle saturation to enhance overall video quality",
                confidence: 0.6
            ))
        }

        return suggestions
    }
    
    // Interprets a high-level editing command and applies changes. For example, creating a highlight reel.
    public func applyEditingCommand(command: String, on videoURL: URL) async throws -> URL {
        let loweredCommand = command.lowercased()
        if loweredCommand.contains("highlight reel") {
            let analysis = try await analyzeVideoContent(videoURL: videoURL)

            // Select scenes with duration between 3 and 10 seconds and non-empty descriptions, sorted by duration descending
            let candidates = analysis.scenes.filter { scene in
                let duration = scene.endTime.seconds - scene.startTime.seconds
                return duration >= 3 && duration <= 10 && !scene.description.isEmpty
            }.sorted { (s1, s2) in
                return (s1.endTime.seconds - s1.startTime.seconds) > (s2.endTime.seconds - s2.startTime.seconds)
            }

            let highlightScenes = Array(candidates.prefix(5))

            // Create video clips for selected scenes
            var clips: [VideoService.VideoClip] = []
            for scene in highlightScenes {
                let duration = CMTime(seconds: scene.endTime.seconds - scene.startTime.seconds, preferredTimescale: 600)
                let clip = VideoService.VideoClip(sourceURL: videoURL, startTime: scene.startTime, duration: duration)
                clips.append(clip)
            }

            return try await videoService.stitchClips(clips)
        }

        if loweredCommand.contains("enhance") {
            var enhancedURL = videoURL

            // Define filter keywords and corresponding filters
            let filters: [(keyword: String, filter: VideoService.VideoFilter)] = [
                ("bright", .brightness(0.1)),
                ("contrast", .contrast(0.1)),
                ("color", .saturation(0.1))
            ]

            for (keyword, filter) in filters {
                if loweredCommand.contains(keyword) {
                    enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: filter)
                }
            }

            // If no specific filter was applied, use a default enhancement
            if enhancedURL == videoURL {
                enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: .brightness(0.05))
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
