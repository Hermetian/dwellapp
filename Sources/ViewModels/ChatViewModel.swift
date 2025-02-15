import SwiftUI
import Combine
import FirebaseAuth
import Core

@MainActor
public class ChatViewModel: ObservableObject {
    @Published public private(set) var channels: [ChatChannel] = []
    @Published public private(set) var messages: [String: [ChatMessage]] = [:] // channelId: [Messages]
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    public init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
        setupSubscriptions()
    }
    
    public func setupSubscriptions() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ ChatViewModel: No user ID available")
            return
        }
        
        print("🔄 ChatViewModel: Setting up subscriptions for user \(userId)")
        chatService.observeChannels(forUserId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                    print("❌ ChatViewModel: Error observing channels: \(error)")
                }
            } receiveValue: { [weak self] channels in
                print("📱 ChatViewModel: Received \(channels.count) channels")
                self?.channels = channels
            }
            .store(in: &cancellables)
    }
    
    public func createChannel(forVideo video: Video) async {
        isLoading = true
        error = nil
        
        print("🔄 ChatViewModel: Creating channel for video \(video.id ?? "")")
        do {
            try await chatService.createNewChannel(forVideo: video)
            print("✅ ChatViewModel: Channel created successfully")
        } catch {
            self.error = error
            print("❌ ChatViewModel: Error creating chat channel: \(error)")
        }
        
        isLoading = false
    }
    
    public func sendMessage(_ text: String, in channelId: String) async {
        do {
            try await chatService.sendMessage(text, in: channelId)
        } catch {
            self.error = error
            print("Error sending message: \(error)")
        }
    }
    
    public func observeMessages(in channelId: String) {
        chatService.observeMessages(in: channelId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                    print("Error observing messages: \(error)")
                }
            } receiveValue: { [weak self] messages in
                self?.messages[channelId] = messages
            }
            .store(in: &cancellables)
    }
    
    public func markChannelAsRead(_ channelId: String) async {
        do {
            try await chatService.markChannelAsRead(channelId)
        } catch {
            self.error = error
            print("Error marking channel as read: \(error)")
        }
    }
    
    public func deleteChannel(_ channelId: String) async {
        isLoading = true
        error = nil
        
        do {
            try await chatService.deleteChannel(channelId)
        } catch {
            self.error = error
            print("Error deleting channel: \(error)")
        }
        
        isLoading = false
    }
    
    public func clearError() {
        error = nil
    }
} 