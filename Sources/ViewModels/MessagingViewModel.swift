import SwiftUI
import Models
import Combine
import Services

@MainActor
public class MessagingViewModel: ObservableObject {
    @Published public var conversations: [Conversation] = []
    @Published public var messages: [Message] = []
    @Published public var selectedConversation: Conversation?
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private let databaseService: DatabaseService
    private var cancellables = Set<AnyCancellable>()
    
    public init(databaseService: DatabaseService? = nil) {
        self.databaseService = databaseService ?? DatabaseService()
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
    
    public func loadMessages(for conversationId: String) {
        isLoading = true
        error = nil
        
        databaseService.getMessagesStream(conversationId: conversationId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] messages in
                self?.messages = messages.sorted { $0.timestamp < $1.timestamp }
            }
            .store(in: &cancellables)
    }
    
    public func sendMessage(_ text: String, in conversationId: String, from userId: String) async throws {
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: userId,
            text: text,
            timestamp: Date(),
            isRead: false
        )
        
        do {
            try await databaseService.sendMessage(message)
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func createOrGetConversation(propertyId: String, tenantId: String, managerId: String) async throws -> String {
        do {
            return try await databaseService.createOrGetConversation(propertyId: propertyId, tenantId: tenantId, managerId: managerId)
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func markConversationAsRead(_ conversationId: String) async throws {
        do {
            try await databaseService.markConversationAsRead(conversationId: conversationId)
        } catch {
            self.error = error
            throw error
        }
    }
} 