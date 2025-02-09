import FirebaseFirestore
import FirebaseAuth
import Foundation

public struct ChatMessage: Identifiable, Codable {
    @DocumentID public var id: String?
    public let channelId: String
    public let senderId: String
    public let content: String
    public let timestamp: Date
    @ServerTimestamp public var serverTimestamp: Timestamp?
    public var isRead: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id
        case channelId
        case senderId
        case content
        case timestamp
        case serverTimestamp
        case isRead
    }
    
    public init(
        id: String? = nil,
        channelId: String,
        senderId: String,
        content: String,
        timestamp: Date = Date(),
        serverTimestamp: Timestamp? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.channelId = channelId
        self.senderId = senderId
        self.content = content
        self.timestamp = timestamp
        self.serverTimestamp = serverTimestamp
        self.isRead = isRead
    }
    
    public var isCurrentUser: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return senderId == currentUserId
    }
} 
