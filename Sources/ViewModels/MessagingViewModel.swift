import Foundation
import Combine

@MainActor
class MessagingViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [Message] = []
    @Published var selectedConversation: Conversation?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var databaseService: DatabaseService!
    private var cancellables = Set<AnyCancellable>()
    
    nonisolated init(databaseService: DatabaseService? = nil) {
        if let databaseService = databaseService {
            self.databaseService = databaseService
        }
        Task { @MainActor in
            if self.databaseService == nil {
                self.databaseService = await DatabaseService()
            }
            await self.setup()
        }
    }
    
    private func setup() async {
        // Initial setup if needed
        // For now, we don't need to do anything here since conversations
        // and messages are loaded on demand
    }
    
    func loadConversations(for userId: String) {
        guard !isLoading else { return }
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
    
    func loadMessages(for conversationId: String) {
        guard !isLoading else { return }
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
                self?.messages = messages
            }
            .store(in: &cancellables)
    }
    
    func sendMessage(content: String, conversationId: String, senderId: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        let message = Message(
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            timestamp: Date(),
            isRead: false
        )
        
        do {
            try await databaseService.sendMessage(message)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createOrGetConversation(propertyId: String, tenantId: String, managerId: String) async -> String? {
        guard !isLoading else { return nil }
        isLoading = true
        error = nil
        
        do {
            let conversationId = try await databaseService.createOrGetConversation(
                propertyId: propertyId,
                tenantId: tenantId,
                managerId: managerId
            )
            return conversationId
        } catch {
            self.error = error
            return nil
        }
    }
    
    func markConversationAsRead(_ conversationId: String) async {
        do {
            try await databaseService.markConversationAsRead(conversationId: conversationId)
        } catch {
            self.error = error
        }
    }
} 