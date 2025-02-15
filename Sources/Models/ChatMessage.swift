import FirebaseFirestore
import FirebaseAuth
import Foundation

public struct ChatMessage: Identifiable, Codable {
    @DocumentID public var id: String?
    public let channelId: String
    public let senderId: String
    public let text: String
    @ServerTimestamp public var timestamp: Timestamp?
    public let attachmentUrl: String?
    public let attachmentType: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case channelId
        case senderId
        case text
        case timestamp
        case attachmentUrl
        case attachmentType
    }
    
    public init(
        id: String? = nil,
        channelId: String,
        senderId: String,
        text: String,
        serverTimestamp: Timestamp? = nil,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil
    ) {
        self.id = id
        self.channelId = channelId
        self.senderId = senderId
        self.text = text
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
    }
    
    public var isCurrentUser: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return senderId == currentUserId
    }
} 
