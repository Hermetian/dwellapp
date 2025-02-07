import FirebaseFirestore
import Foundation

public struct PropertyVideo: Identifiable, Codable {
    @DocumentID public var id: String?
    public let propertyId: String
    public var title: String
    public var description: String
    public let videoUrl: String
    public var thumbnailUrl: String?
    public let uploadDate: Date
    @ServerTimestamp public var serverTimestamp: Timestamp?
    
    public var uniqueIdentifier: String {
        [id ?? UUID().uuidString,
         propertyId,
         title,
         videoUrl].joined(separator: "-")
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId
        case title
        case description
        case videoUrl
        case thumbnailUrl
        case uploadDate
        case serverTimestamp
    }
    
    public init(id: String? = nil,
               propertyId: String,
               title: String,
               description: String,
               videoUrl: String,
               thumbnailUrl: String? = nil,
               uploadDate: Date = Date(),
               serverTimestamp: Timestamp? = nil) {
        self.id = id
        self.propertyId = propertyId
        self.title = title
        self.description = description
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.uploadDate = uploadDate
        self.serverTimestamp = serverTimestamp
    }
} 