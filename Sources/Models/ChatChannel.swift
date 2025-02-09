import FirebaseFirestore
import FirebaseAuth
import Foundation

public struct ChatChannel: Identifiable, Codable {
    @DocumentID public var id: String?
    public let buyerId: String
    public let sellerId: String
    public let propertyId: String
    public let videoId: String
    public let propertySummary: String?
    public var lastMessage: String?
    public var lastMessageTimestamp: Date?
    @ServerTimestamp public var serverTimestamp: Timestamp?
    public var hasUnreadMessages: Bool
    public var otherUserName: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case buyerId
        case sellerId
        case propertyId
        case videoId
        case propertySummary
        case lastMessage
        case lastMessageTimestamp
        case serverTimestamp
        case hasUnreadMessages
        case otherUserName
    }
    
    public init(
        id: String? = nil,
        buyerId: String,
        sellerId: String,
        propertyId: String,
        videoId: String,
        propertySummary: String?,
        lastMessage: String? = nil,
        lastMessageTimestamp: Date? = nil,
        serverTimestamp: Timestamp? = nil,
        hasUnreadMessages: Bool = false,
        otherUserName: String? = nil
    ) {
        self.id = id
        self.buyerId = buyerId
        self.sellerId = sellerId
        self.propertyId = propertyId
        self.videoId = videoId
        self.propertySummary = propertySummary
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.serverTimestamp = serverTimestamp
        self.hasUnreadMessages = hasUnreadMessages
        self.otherUserName = otherUserName
    }
    
    public var isSeller: Bool {
        // Compare with current user ID from AuthService
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return currentUserId == sellerId
    }
    
    public var otherUserId: String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return "" }
        return currentUserId == sellerId ? buyerId : sellerId
    }
} 