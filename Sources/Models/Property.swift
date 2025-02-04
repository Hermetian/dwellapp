import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Property: Identifiable, Codable {
    @DocumentID var id: String?
    let managerId: String
    let title: String
    let description: String
    let price: Double
    let address: String
    let videoUrl: String
    var thumbnailUrl: String?
    let bedrooms: Int
    let bathrooms: Int
    let squareFootage: Double
    var viewCount: Int
    var favoriteCount: Int
    let availableFrom: Date
    let createdAt: Date
    let updatedAt: Date
    @ServerTimestamp var serverTimestamp: Timestamp?
    var amenities: [String: Bool]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case managerId
        case title
        case description
        case price
        case address
        case videoUrl
        case thumbnailUrl
        case bedrooms
        case bathrooms
        case squareFootage
        case viewCount
        case favoriteCount
        case availableFrom
        case createdAt
        case updatedAt
        case serverTimestamp
        case amenities
    }
    
    init(id: String? = nil,
         managerId: String,
         title: String,
         description: String,
         price: Double,
         address: String,
         videoUrl: String,
         thumbnailUrl: String? = nil,
         bedrooms: Int,
         bathrooms: Int,
         squareFootage: Double,
         viewCount: Int = 0,
         favoriteCount: Int = 0,
         availableFrom: Date,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         serverTimestamp: Timestamp? = nil,
         amenities: [String: Bool]? = nil) {
        self.id = id
        self.managerId = managerId
        self.title = title
        self.description = description
        self.price = price
        self.address = address
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.squareFootage = squareFootage
        self.viewCount = viewCount
        self.favoriteCount = favoriteCount
        self.availableFrom = availableFrom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverTimestamp = serverTimestamp
        self.amenities = amenities
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        managerId = try container.decode(String.self, forKey: .managerId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)
        address = try container.decode(String.self, forKey: .address)
        videoUrl = try container.decode(String.self, forKey: .videoUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        bedrooms = try container.decode(Int.self, forKey: .bedrooms)
        bathrooms = try container.decode(Int.self, forKey: .bathrooms)
        squareFootage = try container.decode(Double.self, forKey: .squareFootage)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        favoriteCount = try container.decode(Int.self, forKey: .favoriteCount)
        availableFrom = try container.decode(Date.self, forKey: .availableFrom)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        serverTimestamp = try container.decodeIfPresent(Timestamp.self, forKey: .serverTimestamp)
        amenities = try container.decodeIfPresent([String: Bool].self, forKey: .amenities)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(managerId, forKey: .managerId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encode(address, forKey: .address)
        try container.encode(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(bedrooms, forKey: .bedrooms)
        try container.encode(bathrooms, forKey: .bathrooms)
        try container.encode(squareFootage, forKey: .squareFootage)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(favoriteCount, forKey: .favoriteCount)
        try container.encode(availableFrom, forKey: .availableFrom)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(serverTimestamp, forKey: .serverTimestamp)
        try container.encodeIfPresent(amenities, forKey: .amenities)
    }
} 