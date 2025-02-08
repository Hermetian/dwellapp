import FirebaseFirestore
import Foundation

public enum VideoType: String, Codable, CaseIterable {
    case property = "property"
    case forFun = "forFun"
}

public struct Video: Identifiable, Codable {
    @DocumentID public var id: String?
    public let videoType: VideoType
    public let propertyId: String?  // Optional since it's only used for property videos
    public var title: String
    public var description: String
    public let videoUrl: String
    public var thumbnailUrl: String?
    public let uploadDate: Date
    public let userId: String  // Added to track who uploaded the video
    @ServerTimestamp public var serverTimestamp: Timestamp?
    
    public var uniqueIdentifier: String {
        [id ?? UUID().uuidString,
         propertyId ?? "",
         title,
         videoUrl].joined(separator: "-")
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case videoType
        case propertyId
        case title
        case description
        case videoUrl
        case thumbnailUrl
        case uploadDate
        case userId
        case serverTimestamp
    }
    
    public init(id: String? = nil,
               videoType: VideoType = .forFun,
               propertyId: String? = nil,
               title: String,
               description: String,
               videoUrl: String,
               thumbnailUrl: String? = nil,
               uploadDate: Date = Date(),
               userId: String,
               serverTimestamp: Timestamp? = nil) {
        self.id = id
        self.videoType = videoType
        self.propertyId = propertyId
        self.title = title
        self.description = description
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.uploadDate = uploadDate
        self.userId = userId
        self.serverTimestamp = serverTimestamp
    }
}

public struct VideoItem: Identifiable {
    public let id = UUID()
    public let url: URL
    public var title: String
    public var description: String
    
    public init(url: URL, title: String, description: String) {
        self.url = url
        self.title = title
        self.description = description
    }
} 