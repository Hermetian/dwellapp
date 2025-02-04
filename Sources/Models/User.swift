import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    let name: String
    var profileImageUrl: String?
    var favoriteListings: [String]
    var myListings: [String]
    let createdAt: Date
    var lastActive: Date
    var preferences: [String: Bool]?
    @ServerTimestamp var serverTimestamp: Timestamp?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageUrl
        case favoriteListings
        case myListings
        case createdAt
        case lastActive
        case preferences
        case serverTimestamp
    }
    
    init(id: String? = nil,
         email: String,
         name: String,
         profileImageUrl: String? = nil,
         favoriteListings: [String] = [],
         myListings: [String] = [],
         createdAt: Date = Date(),
         lastActive: Date = Date(),
         preferences: [String: Bool]? = nil,
         serverTimestamp: Timestamp? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.profileImageUrl = profileImageUrl
        self.favoriteListings = favoriteListings
        self.myListings = myListings
        self.createdAt = createdAt
        self.lastActive = lastActive
        self.preferences = preferences
        self.serverTimestamp = serverTimestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        favoriteListings = try container.decode([String].self, forKey: .favoriteListings)
        myListings = try container.decode([String].self, forKey: .myListings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastActive = try container.decode(Date.self, forKey: .lastActive)
        preferences = try container.decodeIfPresent([String: Bool].self, forKey: .preferences)
        serverTimestamp = try container.decodeIfPresent(Timestamp.self, forKey: .serverTimestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(favoriteListings, forKey: .favoriteListings)
        try container.encode(myListings, forKey: .myListings)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastActive, forKey: .lastActive)
        try container.encodeIfPresent(preferences, forKey: .preferences)
        try container.encodeIfPresent(serverTimestamp, forKey: .serverTimestamp)
    }
    
    // MARK: - Helper Methods
    
    func hasFavorited(_ listingId: String) -> Bool {
        return favoriteListings.contains(listingId)
    }
    
    func addToFavorites(_ listingId: String) -> User {
        var updatedFavorites = favoriteListings
        if !updatedFavorites.contains(listingId) {
            updatedFavorites.append(listingId)
        }
        return User(id: id,
                   email: email,
                   name: name,
                   profileImageUrl: profileImageUrl,
                   favoriteListings: updatedFavorites,
                   myListings: myListings,
                   createdAt: createdAt,
                   lastActive: lastActive,
                   preferences: preferences,
                   serverTimestamp: serverTimestamp)
    }
    
    func removeFromFavorites(_ listingId: String) -> User {
        let updatedFavorites = favoriteListings.filter { $0 != listingId }
        return User(id: id,
                   email: email,
                   name: name,
                   profileImageUrl: profileImageUrl,
                   favoriteListings: updatedFavorites,
                   myListings: myListings,
                   createdAt: createdAt,
                   lastActive: lastActive,
                   preferences: preferences,
                   serverTimestamp: serverTimestamp)
    }
} 