import Core
import SwiftUI
import Combine
import Foundation
import FirebaseAuth

@MainActor
public class MessagingViewModel: ObservableObject {
    @Published public var conversations: [ChatChannel] = []
    @Published public var messages: [ChatMessage] = []
    @Published public var selectedConversation: ChatChannel?
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var currentChannelId: String?
    
    private let databaseService: DatabaseService
    private let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    private var messageSubscription: AnyCancellable?
    
    public init(databaseService: DatabaseService = DatabaseService(), chatService: ChatService = ChatService()) {
        self.databaseService = databaseService
        self.chatService = chatService
    }
    
    private func setup() {
        // Initial setup if needed
        // For now, we don't need to do anything here since conversations
        // and messages are loaded on demand
    }
    
    public func loadConversations(for userId: String) {
        isLoading = true
        error = nil
        
        databaseService.getConversationsStream(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] conversations in
                self?.conversations = conversations
            }
            .store(in: &cancellables)
    }
    
    public func loadMessages(for channelId: String) {
        isLoading = true
        error = nil
        messageSubscription?.cancel()
        messageSubscription = chatService.observeMessages(in: channelId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] messages in
                self?.messages = messages.sorted { m1, m2 in
                    guard let t1 = m1.timestamp?.dateValue(),
                          let t2 = m2.timestamp?.dateValue() else {
                        return false
                    }
                    return t1 < t2
                }
            }
    }
    
    // For sending a message in a new or existing deferred channel
    public func sendMessage(_ text: String, 
                          propertyId: String, 
                          tenantId: String, 
                          managerId: String, 
                          videoId: String? = nil) async throws {
        // If we don't yet have a channel, create it now
        if currentChannelId?.isEmpty ?? true {
            currentChannelId = try await databaseService.createOrGetConversation(
                propertyId: propertyId,
                tenantId: tenantId,
                managerId: managerId,
                videoId: videoId
            )
        }
        
        guard let channelId = currentChannelId, !channelId.isEmpty else {
            throw NSError(domain: "MessagingViewModel", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No valid channel ID"])
        }
        
        // Create and send the new message
        let message = ChatMessage(
            id: UUID().uuidString,
            channelId: channelId,
            senderId: tenantId,
            text: text
        )
        try await databaseService.sendMessage(message)
        
        // Ensure we're subscribed to messages for this channel
        loadMessages(for: channelId)
    }
    
    // For sending a message in an existing channel
    public func sendMessage(_ text: String, in channelId: String, from senderId: String) async throws {
        try await chatService.sendMessage(text, in: channelId)
    }
    
    private func subscribeToMessages() {
        guard let channelId = currentChannelId, !channelId.isEmpty else { return }
        
        // Cancel any existing subscription first
        messageSubscription?.cancel()
        
        messageSubscription = databaseService.getMessagesStream(channelId: channelId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Error receiving messages: \(error)")
                }
            } receiveValue: { [weak self] newMessages in
                self?.messages = newMessages.sorted { m1, m2 in
                    guard let t1 = m1.timestamp?.dateValue(),
                          let t2 = m2.timestamp?.dateValue() else {
                        return false
                    }
                    return t1 < t2
                }
            }
    }
    
    public func clearChannelSubscription() {
        messageSubscription?.cancel()
        messageSubscription = nil
        if let channelId = currentChannelId {
            databaseService.removeListener(for: "messages-\(channelId)")
        }
        currentChannelId = nil
        messages = []
    }
    
    // Helper method to create or get conversation (now only used when explicitly needed)
    public func createOrGetConversation(propertyId: String, tenantId: String, managerId: String, videoId: String? = nil) async throws -> String {
        return try await databaseService.createOrGetConversation(propertyId: propertyId, tenantId: tenantId, managerId: managerId, videoId: videoId)
    }
    
    public func markChannelAsRead(_ channelId: String) async throws {
        try await chatService.markChannelAsRead(channelId)
    }
    
    deinit {
            cancellables.removeAll()
    }
}
