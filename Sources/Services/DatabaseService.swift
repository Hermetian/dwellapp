import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

@MainActor
class DatabaseService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Properties Collection
    
    func createProperty(_ property: Property) async throws -> String {
        let docRef = db.collection("properties").document()
        try await docRef.setData(from: property)
        return docRef.documentID
    }
    
    func getProperty(id: String) async throws -> Property {
        let docRef = db.collection("properties").document(id)
        let snapshot = try await docRef.getDocument()
        
        guard let property = try? snapshot.data(as: Property.self) else {
            throw NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Property not found"])
        }
        
        return property
    }
    
    func getPropertiesStream(limit: Int = 10, lastPropertyId: String? = nil) -> AnyPublisher<[Property], Error> {
        var query = db.collection("properties")
            .order(by: "createdAt", descending: true)
        
        if limit > 0 {
            query = query.limit(to: limit)
        }
        
        if let lastId = lastPropertyId {
            let docRef = db.collection("properties").document(lastId)
            // We'll get the document first, then use it as a cursor
            return Future { promise in
                docRef.getDocument { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    guard let snapshot = snapshot else {
                        promise(.failure(NSError(domain: "", code: -1)))
                        return
                    }
                    
                    let finalQuery = query.start(afterDocument: snapshot)
                    let listener = finalQuery.addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        guard let documents = querySnapshot?.documents else {
                            promise(.success([]))
                            return
                        }
                        do {
                            let properties = try documents.map { try $0.data(as: Property.self) }
                            promise(.success(properties))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }
            }
            .eraseToAnyPublisher()
        }
        
        return Future { promise in
            let listener = query.addSnapshotListener { querySnapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    promise(.success([]))
                    return
                }
                do {
                    let properties = try documents.map { try $0.data(as: Property.self) }
                    promise(.success(properties))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateProperty(id: String, data: [String: Any]) async throws {
        try await db.collection("properties").document(id).updateData(data)
    }
    
    func deleteProperty(id: String) async throws {
        try await db.collection("properties").document(id).delete()
    }
    
    func incrementPropertyViewCount(id: String) async throws {
        try await db.collection("properties").document(id).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Favorites
    
    func togglePropertyFavorite(userId: String, propertyId: String, isFavorite: Bool) async throws {
        let batch = db.batch()
        
        let userRef = db.collection("users").document(userId)
        let propertyRef = db.collection("properties").document(propertyId)
        
        if isFavorite {
            batch.updateData([
                "favoriteListings": FieldValue.arrayUnion([propertyId])
            ], forDocument: userRef)
            
            batch.updateData([
                "favoriteCount": FieldValue.increment(Int64(1))
            ], forDocument: propertyRef)
        } else {
            batch.updateData([
                "favoriteListings": FieldValue.arrayRemove([propertyId])
            ], forDocument: userRef)
            
            batch.updateData([
                "favoriteCount": FieldValue.increment(Int64(-1))
            ], forDocument: propertyRef)
        }
        
        try await batch.commit()
    }
    
    func getUserFavorites(userId: String) -> AnyPublisher<[Property], Error> {
        Future { promise in
            let listener = self.db.collection("users").document(userId)
                .addSnapshotListener { documentSnapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let document = documentSnapshot else {
                        promise(.success([]))
                        return
                    }
                    
                    do {
                        let user = try document.data(as: User.self)
                        let favoriteIds = user.favoriteListings
                        
                        if favoriteIds.isEmpty {
                            promise(.success([]))
                            return
                        }
                        
                        self.db.collection("properties")
                            .whereField(FieldPath.documentID(), in: favoriteIds)
                            .getDocuments { querySnapshot, error in
                                if let error = error {
                                    promise(.failure(error))
                                    return
                                }
                                
                                guard let documents = querySnapshot?.documents else {
                                    promise(.success([]))
                                    return
                                }
                                
                                do {
                                    let properties = try documents.map { try $0.data(as: Property.self) }
                                    promise(.success(properties))
                                } catch {
                                    promise(.failure(error))
                                }
                            }
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Messages
    
    func createOrGetConversation(propertyId: String, tenantId: String, managerId: String) async throws -> String {
        let query = db.collection("conversations")
            .whereField("propertyId", isEqualTo: propertyId)
            .whereField("tenantId", isEqualTo: tenantId)
            .whereField("managerId", isEqualTo: managerId)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let existingDoc = snapshot.documents.first {
            return existingDoc.documentID
        }
        
        let conversation = Conversation(propertyId: propertyId,
                                     tenantId: tenantId,
                                     managerId: managerId)
        
        let docRef = db.collection("conversations").document()
        try await docRef.setData(from: conversation)
        return docRef.documentID
    }
    
    func sendMessage(_ message: Message) async throws {
        let batch = db.batch()
        
        let messageRef = db.collection("messages").document()
        try batch.setData(from: message, forDocument: messageRef)
        
        let conversationRef = db.collection("conversations").document(message.conversationId)
        batch.updateData([
            "lastMessageContent": message.content,
            "lastMessageAt": message.timestamp,
            "hasUnreadMessages": true
        ], forDocument: conversationRef)
        
        try await batch.commit()
    }
    
    func getMessagesStream(conversationId: String) -> AnyPublisher<[Message], Error> {
        Future { promise in
            let listener = self.db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp", descending: true)
                .addSnapshotListener { querySnapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        promise(.success([]))
                        return
                    }
                    
                    do {
                        let messages = try documents.map { try $0.data(as: Message.self) }
                        promise(.success(messages))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    func getConversationsStream(userId: String) -> AnyPublisher<[Conversation], Error> {
        Future { promise in
            let listener = self.db.collection("conversations")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("tenantId", isEqualTo: userId),
                    Filter.whereField("managerId", isEqualTo: userId)
                ]))
                .order(by: "lastMessageAt", descending: true)
                .addSnapshotListener { querySnapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        promise(.success([]))
                        return
                    }
                    
                    do {
                        let conversations = try documents.map { try $0.data(as: Conversation.self) }
                        promise(.success(conversations))
                    } catch {
                        promise(.failure(error))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    func markConversationAsRead(conversationId: String) async throws {
        try await db.collection("conversations")
            .document(conversationId)
            .updateData(["hasUnreadMessages": false])
    }
} 