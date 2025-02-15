import FirebaseFirestore
import FirebaseAuth
import Combine

public class ChatService {
    private let db = Firestore.firestore()
    private let databaseService: DatabaseService
    
    public init(databaseService: DatabaseService = DatabaseService()) {
        self.databaseService = databaseService
    }
    
    public func observeChannels(forUserId userId: String) -> AnyPublisher<[ChatChannel], Error> {
        print("🔍 ChatService: Starting channel observation for user \(userId)")
        let query = db.collection("chatChannels")
            .whereFilter(Filter.orFilter([
                Filter.whereField("buyerId", isEqualTo: userId),
                Filter.whereField("sellerId", isEqualTo: userId)
            ]))
            .order(by: "serverTimestamp", descending: true)
        
        return Publishers.QuerySnapshotPublisher(query: query)
            .flatMap { snapshot -> AnyPublisher<[ChatChannel], Error> in
                guard let documents = snapshot?.documents else {
                    print("ℹ️ ChatService: No documents in snapshot")
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                print("📄 ChatService: Received \(documents.count) channel documents")
                
                let channelPublishers = documents.map { document -> AnyPublisher<ChatChannel?, Error> in
                    do {
                        var channel = try document.data(as: ChatChannel.self)
                        print("✅ ChatService: Successfully decoded channel \(document.documentID)")
                        
                        // Fetch other user's data
                        return Future<ChatChannel?, Error> { promise in
                            Task {
                                do {
                                    guard let currentUserId = Auth.auth().currentUser?.uid else {
                                        promise(.success(channel))
                                        return
                                    }
                                    let otherUserId = channel.otherUserId(currentUserId: currentUserId)
                                    let userDoc = try await self.db.collection("users").document(otherUserId).getDocument()
                                    if let userData = try? userDoc.data(as: User.self) {
                                        channel.otherUserName = userData.name
                                        promise(.success(channel))
                                    } else {
                                        promise(.success(channel))
                                    }
                                } catch {
                                    print("❌ ChatService: Error fetching user data: \(error)")
                                    promise(.success(channel))
                                }
                            }
                        }.eraseToAnyPublisher()
                    } catch {
                        print("❌ ChatService: Failed to decode channel \(document.documentID): \(error)")
                        return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                }
                
                return Publishers.MergeMany(channelPublishers)
                    .collect()
                    .map { channels in
                        channels.compactMap { $0 }
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func createNewChannel(forVideo video: Video) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let propertyId = video.propertyId else { return }
        
        // Delegate channel creation to DatabaseService
        _ = try await databaseService.createOrGetConversation(
            propertyId: propertyId,
            tenantId: currentUserId,
            managerId: video.userId,
            videoId: video.id
        )
    }
    
    public func sendMessage(_ text: String, in channelId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            channelId: channelId,
            senderId: currentUserId,
            text: text
        )
        
        try await databaseService.sendMessage(message)
    }
    
    public func observeMessages(in channelId: String) -> AnyPublisher<[ChatMessage], Error> {
        print("🔍 ChatService: Starting message observation for channel \(channelId)")
        let query = db.collection("chatMessages")
            .whereField("channelId", isEqualTo: channelId)
            .order(by: "timestamp", descending: false)
        
        return Publishers.QuerySnapshotPublisher(query: query)
            .map { snapshot -> [ChatMessage] in
                guard let documents = snapshot?.documents else {
                    print("ℹ️ ChatService: No messages in snapshot")
                    return []
                }
                
                print("📄 ChatService: Received \(documents.count) messages")
                let messages = documents.compactMap { document -> ChatMessage? in
                    do {
                        let message = try document.data(as: ChatMessage.self)
                        print("✅ ChatService: Successfully decoded message \(document.documentID)")
                        return message
                    } catch {
                        print("❌ ChatService: Failed to decode message \(document.documentID): \(error)")
                        return nil
                    }
                }
                return messages
            }
            .eraseToAnyPublisher()
    }
    
    public func markChannelAsRead(_ channelId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        try await databaseService.markChannelAsRead(channelId: channelId, forUserId: currentUserId)
    }
    
    public func deleteChannel(_ channelId: String) async throws {
        // Delete all messages in the channel
        let messagesSnapshot = try await db.collection("chatMessages")
            .whereField("channelId", isEqualTo: channelId)
            .getDocuments()
        
        let batch = db.batch()
        
        // Delete messages
        for document in messagesSnapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        // Delete channel
        let channelRef = db.collection("chatChannels").document(channelId)
        batch.deleteDocument(channelRef)
        
        try await batch.commit()
    }
}

extension Publishers {
    struct QuerySnapshotPublisher: Publisher {
        typealias Output = QuerySnapshot?
        typealias Failure = Error
        
        private let query: Query
        
        init(query: Query) {
            self.query = query
        }
        
        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    subscriber.receive(completion: .failure(error))
                    return
                }
                _ = subscriber.receive(snapshot)
            }
            
            subscriber.receive(subscription: QuerySnapshotSubscription(listener: listener))
        }
    }
    
    private class QuerySnapshotSubscription: Subscription {
        private let listener: ListenerRegistration
        
        init(listener: ListenerRegistration) {
            self.listener = listener
        }
        
        func request(_ demand: Subscribers.Demand) {}
        
        func cancel() {
            listener.remove()
        }
    }
} 
