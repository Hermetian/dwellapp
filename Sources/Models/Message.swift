import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation

public struct Message: Identifiable, Codable {
    public let id: String
    public let conversationId: String
    public let senderId: String
    public let text: String
    public let timestamp: Date
    @ServerTimestamp public var serverTimestamp: Timestamp?
    public var isRead: Bool
    public var attachmentUrl: String?
    public var attachmentType: String?
    
    public init(
        id: String,
        conversationId: String,
        senderId: String,
        text: String,
        timestamp: Date,
        serverTimestamp: Timestamp? = nil,
        isRead: Bool = false,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
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
        case text
        case timestamp
        case serverTimestamp
        case isRead
        case attachmentUrl
        case attachmentType
    }
} 