import FirebaseFirestore
import FirebaseFirestoreSwift

public struct User: Identifiable, Codable {
    @DocumentID public var id: String?
    public let email: String
    public let name: String
    public var profileImageUrl: String?
    public var favoriteListings: [String]
    public var bio: String?
    public var phoneNumber: String?
    public var createdAt: Date
    public var updatedAt: Date
    @ServerTimestamp public var serverTimestamp: Timestamp?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageUrl
        case favoriteListings
        case bio
        case phoneNumber
        case createdAt
        case updatedAt
        case serverTimestamp
    }
    
    public init(
        id: String? = nil,
        email: String,
        name: String,
        profileImageUrl: String? = nil,
        favoriteListings: [String] = [],
        bio: String? = nil,
        phoneNumber: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serverTimestamp: Timestamp? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.profileImageUrl = profileImageUrl
        self.favoriteListings = favoriteListings
        self.bio = bio
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverTimestamp = serverTimestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        favoriteListings = try container.decode([String].self, forKey: .favoriteListings)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        serverTimestamp = try container.decodeIfPresent(Timestamp.self, forKey: .serverTimestamp)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(favoriteListings, forKey: .favoriteListings)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(serverTimestamp, forKey: .serverTimestamp)
    }
    
    // MARK: - Helper Methods
    
    public func hasFavorited(_ listingId: String) -> Bool {
        return favoriteListings.contains(listingId)
    }
    
    public func addToFavorites(_ listingId: String) -> User {
        var updatedFavorites = favoriteListings
        if !updatedFavorites.contains(listingId) {
            updatedFavorites.append(listingId)
        }
        return User(id: id,
                   email: email,
                   name: name,
                   profileImageUrl: profileImageUrl,
                   favoriteListings: updatedFavorites,
                   bio: bio,
                   phoneNumber: phoneNumber,
                   createdAt: createdAt,
                   updatedAt: updatedAt,
                   serverTimestamp: serverTimestamp)
    }
    
    public func removeFromFavorites(_ listingId: String) -> User {
        let updatedFavorites = favoriteListings.filter { $0 != listingId }
        return User(id: id,
                   email: email,
                   name: name,
                   profileImageUrl: profileImageUrl,
                   favoriteListings: updatedFavorites,
                   bio: bio,
                   phoneNumber: phoneNumber,
                   createdAt: createdAt,
                   updatedAt: updatedAt,
                   serverTimestamp: serverTimestamp)
    }
} 