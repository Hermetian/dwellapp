import Foundation
import AVFoundation
import CoreImage
import Logging
import FirebaseCrashlytics
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

public struct VideoFeatures {
    public let title: String
    public let description: String
    public let amenities: [String]
}

// AI Assisted Editor Service that integrates simulated LLM calls with our video functions.
public class AIAssistedEditorService {
    private let videoService: VideoService
    private let cloudService: GoogleCloudService
    private let logger = Logger(label: "AIAssistedEditorService")
    
    public init(videoService: VideoService) throws {
        self.videoService = videoService
        logger.info("Initializing AIAssistedEditorService")
        do {
            self.cloudService = try GoogleCloudService()
            logger.info("Successfully initialized GoogleCloudService")
        } catch {
            logger.error("Failed to initialize GoogleCloudService: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
    }
    
    // Analyzes video content (scene segmentation, transcript & quality issues)
    public func analyzeVideoContent(videoURL: URL) async throws -> AIVideoAnalysis {
        logger.info("Starting video content analysis for \(videoURL.lastPathComponent)")
        do {
            let analysisResult = try await cloudService.analyzeVideo(url: videoURL)
            logger.info("Video analysis completed successfully with \(analysisResult.scenes.count) scenes detected")
            return AIVideoAnalysis(
                scenes: analysisResult.scenes,
                transcript: analysisResult.transcript,
                qualityIssues: analysisResult.qualityIssues
            )
        } catch {
            logger.error("Video content analysis failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
    }
    
    // Generates a list of recommended edits based on the analysis.
    public func generateEditingRecommendations(analysis: AIVideoAnalysis) async throws -> [AIAssistedEditSuggestion] {
        logger.info("Generating editing recommendations based on video analysis")
        var suggestions = [AIAssistedEditSuggestion]()

        // Process quality issues using advanced heuristics
        if let issues = analysis.qualityIssues, !issues.isEmpty {
            logger.info("Processing \(issues.count) quality issues")
            for issue in issues {
                if issue.lowercased().contains("scene change") {
                    let speedAdjustment: Float = issue.components(separatedBy: ",").count > 1 ? 0.75 : 0.85
                    logger.info("Suggesting speed adjustment for rapid scene changes")
                    suggestions.append(AIAssistedEditSuggestion(
                        type: .speedAdjustment(rate: speedAdjustment),
                        suggestionText: "Adjust video speed to smooth out rapid scene changes",
                        confidence: 0.8
                    ))
                }
                
                if issue.lowercased().contains("audio") {
                    if let scene = analysis.scenes.first(where: { $0.description.lowercased().contains("poor audio") || $0.description.lowercased().contains("low audio") }) {
                        logger.info("Suggesting trim for poor audio segment")
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
            logger.info("Analyzing transcript sentiment")
            do {
                let sentimentAnalysis = try await cloudService.analyzeContent(text: transcript)
                logger.info("Sentiment analysis completed with score: \(sentimentAnalysis.score)")
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
            } catch {
                logger.error("Sentiment analysis failed: \(error.localizedDescription)")
                Crashlytics.crashlytics().record(error: error)
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

        logger.info("Generated \(suggestions.count) editing recommendations")
        return suggestions
    }
    
    // Interprets a high-level editing command and applies changes. For example, creating a highlight reel.
    public func applyEditingCommand(command: String, on videoURL: URL) async throws -> URL {
        logger.info("Processing editing command: \(command)")
        let loweredCommand = command.lowercased()
        if loweredCommand.contains("highlight reel") {
            logger.info("Creating highlight reel")
            let analysis = try await analyzeVideoContent(videoURL: videoURL)

            // Select scenes with duration between 3 and 10 seconds and non-empty descriptions, sorted by duration descending
            let candidates = analysis.scenes.filter { scene in
                let duration = scene.endTime.seconds - scene.startTime.seconds
                return duration >= 3 && duration <= 10 && !scene.description.isEmpty
            }.sorted { (s1, s2) in
                return (s1.endTime.seconds - s1.startTime.seconds) > (s2.endTime.seconds - s2.startTime.seconds)
            }

            let highlightScenes = Array(candidates.prefix(5))
            logger.info("Selected \(highlightScenes.count) scenes for highlight reel")

            // Create video clips for selected scenes
            var clips: [VideoService.VideoClip] = []
            for scene in highlightScenes {
                let duration = CMTime(seconds: scene.endTime.seconds - scene.startTime.seconds, preferredTimescale: 600)
                let clip = VideoService.VideoClip(sourceURL: videoURL, startTime: scene.startTime, duration: duration)
                clips.append(clip)
            }

            do {
                let result = try await videoService.stitchClips(clips)
                logger.info("Successfully created highlight reel")
                return result
            } catch {
                logger.error("Failed to create highlight reel: \(error.localizedDescription)")
                Crashlytics.crashlytics().record(error: error)
                throw error
            }
        }

        if loweredCommand.contains("enhance") {
            logger.info("Applying enhancement filters")
            var enhancedURL = videoURL

            // Define filter keywords and corresponding filters
            let filters: [(keyword: String, filter: VideoService.VideoFilter)] = [
                ("bright", .brightness(0.1)),
                ("contrast", .contrast(0.1)),
                ("color", .saturation(0.1))
            ]

            for (keyword, filter) in filters {
                if loweredCommand.contains(keyword) {
                    logger.info("Applying \(keyword) filter")
                    do {
                        enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: filter)
                    } catch {
                        logger.error("Failed to apply \(keyword) filter: \(error.localizedDescription)")
                        Crashlytics.crashlytics().record(error: error)
                        throw error
                    }
                }
            }

            // If no specific filter was applied, use a default enhancement
            if enhancedURL == videoURL {
                logger.info("Applying default brightness enhancement")
                do {
                    enhancedURL = try await videoService.applyFilter(to: enhancedURL, filter: .brightness(0.05))
                } catch {
                    logger.error("Failed to apply default enhancement: \(error.localizedDescription)")
                    Crashlytics.crashlytics().record(error: error)
                    throw error
                }
            }

            return enhancedURL
        }

        logger.info("No matching command found, returning original video")
        return videoURL
    }
    
    // Generates content suggestions (title, description, amenities) based on video content and property info.
    public func getContentSuggestions(for videoURL: URL, property: Property?) async throws -> (title: String, description: String, amenities: [String]) {
        logger.info("Generating content suggestions for \(videoURL.lastPathComponent)")
        do {
            let videoAnalysis = try await analyzeVideoContent(videoURL: videoURL)
            
            var titleComponents: [String] = []
            for scene in videoAnalysis.scenes where scene.description.contains("exterior") || scene.description.contains("interior") {
                titleComponents.append(scene.description)
            }
            
            if let transcript = videoAnalysis.transcript {
                let sentimentAnalysis = try await cloudService.analyzeContent(text: transcript)
                logger.info("Content sentiment analysis completed with score: \(sentimentAnalysis.score)")
                
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
                
                logger.info("Generated content suggestions with \(amenities.count) amenities detected")
                return (title: title, description: description, amenities: Array(amenities))
            }
            
            logger.error("No transcript available for content generation")
            throw NSError(domain: "AIAssistedEditorService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No transcript available for content generation"])
        } catch {
            logger.error("Failed to generate content suggestions: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
    }
    
    public func extractKeyFeatures(from transcript: String) async throws -> VideoFeatures {
        logger.info("Extracting key features from transcript")
        do {
            // Use Google Cloud Natural Language API to analyze the transcript
            let analysis = try await cloudService.analyzeContent(text: transcript)
            
            // Extract entities and categorize them
            var amenities: [String] = []
            var locationDetails: [String] = []
            var propertyFeatures: [String] = []
            
            for entity in analysis.entities {
                switch entity.type.lowercased() {
                case "location":
                    locationDetails.append(entity.name)
                case "consumer_good", "other":
                    if entity.name.lowercased().contains("bedroom") || 
                       entity.name.lowercased().contains("bathroom") ||
                       entity.name.lowercased().contains("kitchen") {
                        amenities.append(entity.name)
                    } else {
                        propertyFeatures.append(entity.name)
                    }
                default:
                    break
                }
            }
            
            // Generate title
            let title = locationDetails.isEmpty ? "Property Tour" : "Tour of \(locationDetails.first!)"
            
            // Generate description
            var description = "This property features"
            if !amenities.isEmpty {
                description += " \(amenities.joined(separator: ", "))"
            }
            if !propertyFeatures.isEmpty {
                description += " with \(propertyFeatures.joined(separator: ", "))"
            }
            description += "."
            
            logger.info("Successfully extracted features: \(amenities.count) amenities, \(propertyFeatures.count) features")
            return VideoFeatures(title: title, description: description, amenities: amenities)
        } catch {
            logger.error("Failed to extract features: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
    }
}
