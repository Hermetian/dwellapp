import FirebaseFirestore
import Foundation

public struct Conversation: Identifiable, Codable {
    public let id: String
    public let participants: [String]
    public let lastMessage: String?
    public let lastMessageTimestamp: Date?
    public let propertyId: String?
    public var hasUnreadMessages: Bool
    
    public init(
        id: String,
        participants: [String],
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil,
        propertyId: String? = nil,
        hasUnreadMessages: Bool = false
    ) {
        self.id = id
        self.participants = participants
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.propertyId = propertyId
        self.hasUnreadMessages = hasUnreadMessages
    }
    
    // Convenience initializer for creating new conversations
    public static func create(propertyId: String, tenantId: String, managerId: String) -> Conversation {
        return Conversation(
            id: UUID().uuidString,
            participants: [tenantId, managerId],
            propertyId: propertyId,
            hasUnreadMessages: false
        )
    }
} 