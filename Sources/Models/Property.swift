import FirebaseFirestore
import Foundation

public enum PropertyTypes: String {
    case vacationRental = "Vacation Rental"
    case roomRent = "Room (Rent)"
    case propertyRent = "Property (Rent)"
    case condoTownhouseBuy = "Condo/Townhouse (Buy)"
    case houseBuy = "House (Buy)"
    
    public static var allCases: [String] {
        [
            vacationRental.rawValue,
            roomRent.rawValue,
            propertyRent.rawValue,
            condoTownhouseBuy.rawValue,
            houseBuy.rawValue
        ]
    }
}

public struct Property: Identifiable, Codable, Hashable {
    @DocumentID public var id: String?
    public let managerId: String
    public var title: String
    public var description: String
    public var price: Double
    public var address: String
    public var videoIds: [String]
    public var thumbnailUrl: String?
    public var bedrooms: Int
    public var bathrooms: Double
    public var squareFootage: Double
    public var viewCount: Int
    public var favoriteCount: Int
    public var availableFrom: Date
    public let createdAt: Date
    public var updatedAt: Date
    @ServerTimestamp public var serverTimestamp: Timestamp?
    public var amenities: [String: Bool]?
    public var imageUrl: String?
    public var type: String
    public let userId: String
    public var isAvailable: Bool
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Property, rhs: Property) -> Bool {
        lhs.id == rhs.id
    }
    
    public var uniqueIdentifier: String {
        [id ?? UUID().uuidString,
         title,
         address,
         String(price),
         String(bedrooms),
         String(bathrooms)].joined(separator: "-")
    }
    
    public var dictionary: [String: Any] {
        [
            "managerId": managerId,
            "title": title,
            "description": description,
            "price": price,
            "address": address,
            "videoIds": videoIds,
            "thumbnailUrl": thumbnailUrl as Any,
            "bedrooms": bedrooms,
            "bathrooms": bathrooms,
            "squareFootage": squareFootage,
            "availableFrom": availableFrom,
            "amenities": amenities as Any,
            "type": type,
            "userId": userId,
            "isAvailable": isAvailable
        ]
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case managerId
        case title
        case description
        case price
        case address
        case videoIds
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
        case imageUrl
        case type
        case userId
        case isAvailable
    }
    
    public init(
        id: String? = nil,
        managerId: String,
        title: String,
        description: String,
        price: Double,
        address: String,
        videoIds: [String] = [],
        thumbnailUrl: String? = nil,
        bedrooms: Int,
        bathrooms: Double,
        squareFootage: Double,
        viewCount: Int = 0,
        favoriteCount: Int = 0,
        availableFrom: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serverTimestamp: Timestamp? = nil,
        amenities: [String: Bool]? = nil,
        imageUrl: String? = nil,
        type: String,
        userId: String,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.managerId = managerId
        self.title = title
        self.description = description
        self.price = price
        self.address = address
        self.videoIds = videoIds
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
        self.imageUrl = imageUrl
        self.type = type
        self.userId = userId
        self.isAvailable = isAvailable
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        managerId = try container.decode(String.self, forKey: .managerId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)
        address = try container.decode(String.self, forKey: .address)
        videoIds = try container.decodeIfPresent([String].self, forKey: .videoIds) ?? []
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        bedrooms = try container.decode(Int.self, forKey: .bedrooms)
        bathrooms = try container.decode(Double.self, forKey: .bathrooms)
        squareFootage = try container.decode(Double.self, forKey: .squareFootage)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        favoriteCount = try container.decode(Int.self, forKey: .favoriteCount)
        availableFrom = try container.decode(Date.self, forKey: .availableFrom)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        serverTimestamp = try container.decodeIfPresent(Timestamp.self, forKey: .serverTimestamp)
        amenities = try container.decodeIfPresent([String: Bool].self, forKey: .amenities)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        type = try container.decode(String.self, forKey: .type)
        userId = try container.decode(String.self, forKey: .userId)
        isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(managerId, forKey: .managerId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encode(address, forKey: .address)
        try container.encodeIfPresent(videoIds, forKey: .videoIds)
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
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(type, forKey: .type)
        try container.encode(userId, forKey: .userId)
        try container.encode(isAvailable, forKey: .isAvailable)
    }
    
    public static var preview: Property {
        Property(
            managerId: "preview-manager",
            title: "Sample Property",
            description: "A beautiful property for preview purposes",
            price: 1500,
            address: "123 Preview St",
            videoIds: [],
            bedrooms: 2,
            bathrooms: 2,
            squareFootage: 1200,
            availableFrom: Date(),
            type: "Property (Rent)",
            userId: "preview-user"
        )
    }
} 