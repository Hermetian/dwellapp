import Core
import SwiftUI
import ViewModels

public struct MessagingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var messagingViewModel = MessagingViewModel()
    
    public var body: some View {
        NavigationView {
            Group {
                if messagingViewModel.isLoading {
                    ProgressView()
                } else if messagingViewModel.conversations.isEmpty {
                    EmptyConversationsView()
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
        }
        .onAppear {
            if let userId = appViewModel.authViewModel.currentUser?.id {
                messagingViewModel.loadConversations(for: userId)
            }
        }
        .alert("Error", isPresented: .constant(messagingViewModel.error != nil)) {
            Button("OK") {
                messagingViewModel.error = nil
            }
        } message: {
            Text(messagingViewModel.error?.localizedDescription ?? "")
        }
    }
    
    private var conversationsList: some View {
        List(messagingViewModel.conversations) { conversation in
            NavigationLink {
                ConversationView(conversation: conversation)
            } label: {
                ConversationRow(conversation: conversation)
            }
        }
        .listStyle(.inset)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    @StateObject private var propertyViewModel = PropertyViewModel()
    
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
                if conversation.hasUnreadMessages {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if let propertyId = conversation.propertyId {
                Task {
                    await propertyViewModel.loadProperty(id: propertyId)
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

struct ConversationView: View {
    let conversation: Conversation
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var messagingViewModel = MessagingViewModel()
    @State private var messageText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
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
        .navigationTitle("Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            messagingViewModel.loadMessages(for: conversation.id)
            Task {
                do {
                    try await messagingViewModel.markConversationAsRead(conversation.id)
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
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let messageToSend = messageText
        messageText = "" // Clear immediately for better UX
        
        Task {
            do {
                try await messagingViewModel.sendMessage(messageToSend, in: conversation.id, from: userId)
            } catch {
                showError = true
                errorMessage = error.localizedDescription
                messageText = messageToSend // Restore message text if send failed
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    public var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(isFromCurrentUser ? Color.blue : Color.secondary.opacity(0.2))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(Self.timeFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer()
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
    MessagingView()
        .environmentObject(AppViewModel())
} 