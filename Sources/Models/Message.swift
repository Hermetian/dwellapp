import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let conversationId: String
    let senderId: String
    let content: String
    let timestamp: Date
    var isRead: Bool
    var attachmentUrl: String?
    var attachmentType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case content
        case timestamp
        case isRead
        case attachmentUrl
        case attachmentType
    }
}

struct Conversation: Identifiable, Codable {
    @DocumentID var id: String?
    let propertyId: String
    let tenantId: String
    let managerId: String
    let createdAt: Date
    var lastMessageAt: Date
    var lastMessageContent: String
    var hasUnreadMessages: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId
        case tenantId
        case managerId
        case createdAt
        case lastMessageAt
        case lastMessageContent
        case hasUnreadMessages
    }
    
    init(id: String? = nil,
         propertyId: String,
         tenantId: String,
         managerId: String,
         createdAt: Date = Date(),
         lastMessageAt: Date = Date(),
         lastMessageContent: String = "",
         hasUnreadMessages: Bool = false) {
        self.id = id
        self.propertyId = propertyId
        self.tenantId = tenantId
        self.managerId = managerId
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.lastMessageContent = lastMessageContent
        self.hasUnreadMessages = hasUnreadMessages
    }
} 