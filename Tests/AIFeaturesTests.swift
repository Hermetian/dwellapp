import XCTest
@testable import Services

final class AIFeaturesTests: XCTestCase {
    var videoService: VideoService!
    var aiService: AIAssistedEditorService!
    
    override func setUp() {
        super.setUp()
        videoService = VideoService()
        aiService = AIAssistedEditorService(videoService: videoService)
    }
    
    override func tearDown() {
        videoService = nil
        aiService = nil
        super.tearDown()
    }
    
    func testVideoAnalysis() async throws {
        // Get the test video URL
        guard let testVideoURL = Bundle.module.url(forResource: "sample_property", withExtension: "mp4") else {
            XCTFail("Test video not found")
            return
        }
        
        // Test video analysis
        let analysis = try await aiService.analyzeVideoContent(videoURL: testVideoURL)
        
        // Verify scenes were detected
        XCTAssertFalse(analysis.scenes.isEmpty, "Should detect at least one scene")
        
        // Verify transcript was generated
        XCTAssertNotNil(analysis.transcript, "Should generate transcript")
        
        // Verify quality analysis
        XCTAssertNotNil(analysis.qualityIssues, "Should perform quality analysis")
    }
    
    func testEditingRecommendations() async throws {
        guard let testVideoURL = Bundle.module.url(forResource: "sample_property", withExtension: "mp4") else {
            XCTFail("Test video not found")
            return
        }
        
        // Get video analysis first
        let analysis = try await aiService.analyzeVideoContent(videoURL: testVideoURL)
        
        // Test editing recommendations
        let suggestions = try await aiService.generateEditingRecommendations(analysis: analysis)
        
        // Verify we get recommendations
        XCTAssertFalse(suggestions.isEmpty, "Should generate at least one suggestion")
        
        // Verify suggestion confidence scores
        for suggestion in suggestions {
            XCTAssertGreaterThan(suggestion.confidence, 0, "Confidence should be greater than 0")
            XCTAssertLessThanOrEqual(suggestion.confidence, 1, "Confidence should be less than or equal to 1")
        }
    }
    
    func testContentSuggestions() async throws {
        guard let testVideoURL = Bundle.module.url(forResource: "sample_property", withExtension: "mp4") else {
            XCTFail("Test video not found")
            return
        }
        
        // Test content suggestions without property
        let suggestions = try await aiService.getContentSuggestions(for: testVideoURL, property: nil)
        
        // Verify title
        XCTAssertFalse(suggestions.title.isEmpty, "Should generate a title")
        
        // Verify description
        XCTAssertFalse(suggestions.description.isEmpty, "Should generate a description")
        
        // Verify amenities
        XCTAssertFalse(suggestions.amenities.isEmpty, "Should detect some amenities")
    }
    
    func testHighlightReelGeneration() async throws {
        guard let testVideoURL = Bundle.module.url(forResource: "sample_property", withExtension: "mp4") else {
            XCTFail("Test video not found")
            return
        }
        
        // Test highlight reel generation
        let highlightURL = try await aiService.applyEditingCommand(
            command: "create a highlight reel",
            on: testVideoURL
        )
        
        // Verify the output video exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: highlightURL.path))
        
        // Verify the duration is shorter than the original
        let originalDuration = try await videoService.getVideoDuration(url: testVideoURL)
        let highlightDuration = try await videoService.getVideoDuration(url: highlightURL)
        XCTAssertLessThan(highlightDuration, originalDuration, "Highlight reel should be shorter than original")
    }
} 