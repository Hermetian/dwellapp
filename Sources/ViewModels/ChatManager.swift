import SwiftUI
import Combine
import FirebaseAuth
import Core

@MainActor
public class ChatManager: ObservableObject {
    @Published public private(set) var channels: [ChatChannel] = []
    @Published public private(set) var messages: [String: [ChatMessage]] = [:] // channelId: [Messages]
    private let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    public init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        chatService.observeChannels(forUserId: userId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Error observing channels: \(error)")
                }
            } receiveValue: { [weak self] channels in
                self?.channels = channels
            }
            .store(in: &cancellables)
    }
    
    public func createChannel(forVideo video: Video) async throws {
        try await chatService.createNewChannel(forVideo: video)
    }
    
    public func sendMessage(_ text: String, in channelId: String) async throws {
        try await chatService.sendMessage(text, in: channelId)
    }
    
    public func observeMessages(in channelId: String) {
        chatService.observeMessages(in: channelId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Error observing messages: \(error)")
                }
            } receiveValue: { [weak self] messages in
                self?.messages[channelId] = messages
            }
            .store(in: &cancellables)
    }
    
    public func markChannelAsRead(_ channelId: String) async throws {
        try await chatService.markChannelAsRead(channelId)
    }
    
    public func deleteChannel(_ channelId: String) async throws {
        try await chatService.deleteChannel(channelId)
    }
} 