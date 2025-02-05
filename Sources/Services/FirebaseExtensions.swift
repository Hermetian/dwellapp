import FirebaseFirestore
import Foundation

extension User {
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "name": name,
            "favoriteListings": favoriteListings,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        if let bio = bio {
            data["bio"] = bio
        }
        if let phoneNumber = phoneNumber {
            data["phoneNumber"] = phoneNumber
        }
        return data
    }
    
    static func fromFirestore(_ snapshot: DocumentSnapshot) -> User? {
        guard let data = snapshot.data() else { return nil }
        return User(
            id: snapshot.documentID,
            email: data["email"] as? String ?? "",
            name: data["name"] as? String ?? "",
            profileImageUrl: data["profileImageUrl"] as? String,
            favoriteListings: data["favoriteListings"] as? [String] ?? [],
            bio: data["bio"] as? String,
            phoneNumber: data["phoneNumber"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
} 