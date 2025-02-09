import FirebaseFirestore
import FirebaseAuth
import Combine

public class ChatService {
    private let db = Firestore.firestore()
    
    public init() {}
    
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
                                    let otherUserId = channel.otherUserId
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
        
        print("🔄 ChatService: Checking for existing channel - videoId: \(video.id ?? ""), buyerId: \(currentUserId)")
        
        // Check if channel already exists
        let querySnapshot = try await db.collection("chatChannels")
            .whereField("videoId", isEqualTo: video.id ?? "")
            .whereField("buyerId", isEqualTo: currentUserId)
            .getDocuments()
        
        if !querySnapshot.documents.isEmpty {
            print("ℹ️ ChatService: Channel already exists")
            return // Channel already exists
        }
        
        print("🆕 ChatService: Creating new channel")
        
        // Create new channel
        let channel = ChatChannel(
            buyerId: currentUserId,
            sellerId: video.userId,
            propertyId: propertyId,
            videoId: video.id ?? "",
            propertySummary: video.title,
            lastMessageTimestamp: Date(),
            serverTimestamp: Timestamp(date: Date()),
            hasUnreadMessages: false
        )
        
        let docRef = db.collection("chatChannels").document()
        print("📝 ChatService: Setting data for channel \(docRef.documentID)")
        try docRef.setData(from: channel)
        
        // Update the timestamp using server timestamp
        try await docRef.updateData([
            "serverTimestamp": FieldValue.serverTimestamp(),
            "lastMessageTimestamp": FieldValue.serverTimestamp()
        ])
        print("✅ ChatService: Channel created and timestamps updated")
    }
    
    public func sendMessage(_ content: String, in channelId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let message = ChatMessage(
            channelId: channelId,
            senderId: currentUserId,
            content: content
        )
        
        let batch = db.batch()
        
        // Add message
        let messageRef = db.collection("chatMessages").document()
        try batch.setData(from: message, forDocument: messageRef)
        
        // Update channel
        let channelRef = db.collection("chatChannels").document(channelId)
        batch.updateData([
            "lastMessage": content,
            "lastMessageTimestamp": Date(),
            "hasUnreadMessages": true
        ], forDocument: channelRef)
        
        try await batch.commit()
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
        let ref = db.collection("chatChannels").document(channelId)
        try await ref.updateData(["hasUnreadMessages": false])
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
