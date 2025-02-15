import FirebaseFirestore
import Foundation

public struct ChatChannel: Identifiable, Codable {
    @DocumentID public var id: String?
    public let buyerId: String
    public let sellerId: String
    public let propertyId: String
    public let videoId: String
    public var chatTitle: String?
    public var lastMessage: String?
    public var lastMessageTimestamp: Date?
    @ServerTimestamp public var serverTimestamp: Timestamp?
    public var lastSenderId: String?
    public var isRead: Bool
    public var otherUserName: String?  // This will be populated in memory but not stored in Firestore
    
    private enum CodingKeys: String, CodingKey {
        case id
        case buyerId
        case sellerId
        case propertyId
        case videoId
        case chatTitle
        case lastMessage
        case lastMessageTimestamp
        case serverTimestamp
        case lastSenderId
        case isRead
        // Note: otherUserName is intentionally omitted from CodingKeys
    }
    
    public init(
        id: String? = nil,
        buyerId: String,
        sellerId: String,
        propertyId: String,
        videoId: String,
        chatTitle: String? = nil,
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil,
        serverTimestamp: Timestamp? = nil,
        lastSenderId: String? = nil,
        isRead: Bool = true
    ) {
        self.id = id
        self.buyerId = buyerId
        self.sellerId = sellerId
        self.propertyId = propertyId
        self.videoId = videoId
        self.chatTitle = chatTitle
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.serverTimestamp = serverTimestamp
        self.lastSenderId = lastSenderId
        self.isRead = isRead
    }
    
    public func isSeller(currentUserId: String) -> Bool {
        return currentUserId == sellerId
    }
    
    public func otherUserId(currentUserId: String) -> String {
        return currentUserId == sellerId ? buyerId : sellerId
    }
} 