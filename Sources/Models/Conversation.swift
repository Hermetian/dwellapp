import FirebaseFirestore
import FirebaseFirestoreSwift

public struct Conversation: Identifiable, Codable {
    @DocumentID public var id: String?
    public let propertyId: String
    public let tenantId: String
    public let managerId: String
    public var lastMessage: String?
    public var lastMessageTimestamp: Date?
    public var hasUnreadMessages: Bool
    @ServerTimestamp public var serverTimestamp: Timestamp?
    
    public init(
        id: String? = nil,
        propertyId: String,
        tenantId: String,
        managerId: String,
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil,
        hasUnreadMessages: Bool = false,
        serverTimestamp: Timestamp? = nil
    ) {
        self.id = id
        self.propertyId = propertyId
        self.tenantId = tenantId
        self.managerId = managerId
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.hasUnreadMessages = hasUnreadMessages
        self.serverTimestamp = serverTimestamp
    }
} 