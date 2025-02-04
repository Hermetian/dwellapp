import FirebaseFirestore
import FirebaseFirestoreSwift

public struct Message: Identifiable, Codable {
    @DocumentID public var id: String?
    public let conversationId: String
    public let senderId: String
    public let content: String
    public let timestamp: Date
    @ServerTimestamp public var serverTimestamp: Timestamp?
    public var isRead: Bool
    public var attachmentUrl: String?
    public var attachmentType: String?
    
    public init(
        id: String? = nil,
        conversationId: String,
        senderId: String,
        content: String,
        timestamp: Date = Date(),
        serverTimestamp: Timestamp? = nil,
        isRead: Bool = false,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.serverTimestamp = serverTimestamp
        self.isRead = isRead
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case content
        case timestamp
        case serverTimestamp
        case isRead
        case attachmentUrl
        case attachmentType
    }
} 