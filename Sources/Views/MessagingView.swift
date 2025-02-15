import Core
import SwiftUI
import ViewModels

public struct MessagingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var messagingViewModel: MessagingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    let propertyId: String
    let managerId: String
    let videoId: String?
    
    public init(propertyId: String, managerId: String, videoId: String? = nil) {
        self.propertyId = propertyId
        self.managerId = managerId
        self.videoId = videoId
        _messagingViewModel = StateObject(wrappedValue: MessagingViewModel())
    }
    
    public var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(messagingViewModel.messages) { message in
                        MessageBubble(message: message, 
                                    isFromCurrentUser: message.senderId == appViewModel.authViewModel.currentUser?.id)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
                .disabled(messageText.isEmpty)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onDisappear {
            messagingViewModel.clearChannelSubscription()
        }
        .onAppear {
            Task {
                // If no conversation/channel exists, create or get it
                if messagingViewModel.currentChannelId?.isEmpty ?? true {
                    if let userId = appViewModel.authViewModel.currentUser?.id {
                        do {
                            messagingViewModel.currentChannelId = try await messagingViewModel.createOrGetConversation(propertyId: propertyId, tenantId: userId, managerId: managerId, videoId: videoId)
                        } catch {
                            print("Error creating/getting conversation: \(error)")
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                // Load messages for the conversation if we have a channel id
                if let channelId = messagingViewModel.currentChannelId {
                    messagingViewModel.loadMessages(for: channelId)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty,
              let userId = appViewModel.authViewModel.currentUser?.id else {
            return
        }
        
        let messageToSend = messageText
        messageText = ""  // Clear the input field immediately
        
        Task {
            do {
                try await messagingViewModel.sendMessage(
                    messageToSend,
                    propertyId: propertyId,
                    tenantId: userId,
                    managerId: managerId,
                    videoId: videoId
                )
            } catch {
                // Handle error (perhaps show an alert)
                print("Error sending message: \(error)")
                messageText = messageToSend // Restore message text if send failed
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            Text(message.text)
                .padding()
                .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(20)
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}

struct ConversationRow: View {
    let conversation: ChatChannel
    @StateObject private var propertyViewModel = PropertyViewModel()
    @EnvironmentObject private var appViewModel: AppViewModel
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()
    
    private var isSeller: Bool {
        conversation.isSeller(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    private var otherUserId: String {
        conversation.otherUserId(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Property Thumbnail
            AsyncImage(url: URL(string: propertyViewModel.property?.thumbnailUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "house.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                // Property Title
                Text(propertyViewModel.property?.title ?? "Property")
                    .font(.headline)
                    .lineLimit(1)
                
                // Last Message
                Text(conversation.lastMessage ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(isSeller ? "Buyer" : "Seller")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Time
                if let timestamp = conversation.lastMessageTimestamp {
                    Text(formatDate(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Unread indicator
                if !conversation.isRead && conversation.lastSenderId != appViewModel.authViewModel.currentUser?.id {
                    Spacer()
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .onAppear {
            if !conversation.propertyId.isEmpty {
                Task {
                    await propertyViewModel.loadProperty(id: conversation.propertyId)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.dateFormatter.string(from: date)
        }
    }
}

public struct ConversationView: View {
    let conversation: ChatChannel
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var messagingViewModel = MessagingViewModel()
    @State private var messageText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isSeller: Bool {
        conversation.isSeller(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    private var otherUserId: String {
        conversation.otherUserId(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    public var body: some View {
        VStack {
            // Messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messagingViewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == appViewModel.authViewModel.currentUser?.id
                        )
                    }
                }
                .padding()
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(isSeller ? "Chat with Buyer" : "Chat with Seller")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if let channelId = conversation.id {
                messagingViewModel.loadMessages(for: channelId)
            }
            Task {
                do {
                    if let channelId = conversation.id {
                        try await messagingViewModel.markChannelAsRead(channelId)
                    }
                } catch {
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendMessage() {
        guard let userId = appViewModel.authViewModel.currentUser?.id,
              let channelId = conversation.id,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let messageToSend = messageText
        messageText = "" // Clear immediately for better UX
        
        Task {
            do {
                try await messagingViewModel.sendMessage(messageToSend, in: channelId, from: userId)
            } catch {
                showError = true
                errorMessage = error.localizedDescription
                messageText = messageToSend // Restore message text if send failed
            }
        }
    }
}

struct EmptyConversationsView: View {
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Messages")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start browsing properties to connect with property managers")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationView {
        MessagingView(propertyId: "sample-property-id", managerId: "123", videoId: nil)
        .environmentObject(AppViewModel())
    }
} 