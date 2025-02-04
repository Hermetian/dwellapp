import SwiftUI

struct MessagingView: View {
    @StateObject private var messagingViewModel = MessagingViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
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
            if let userId = authViewModel.currentUser?.id {
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Property Thumbnail
            AsyncImage(url: URL(string: "")) { image in // TODO: Add property thumbnail URL
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
                Text("Property Title") // TODO: Add property title
                    .font(.headline)
                    .lineLimit(1)
                
                // Last Message
                Text(conversation.lastMessageContent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Time
                Text(formatDate(conversation.lastMessageAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Unread indicator
                if conversation.hasUnreadMessages {
                    Circle()
                        .fill(.blue)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}

struct ConversationView: View {
    let conversation: Conversation
    @StateObject private var messagingViewModel = MessagingViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            // Messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messagingViewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == authViewModel.currentUser?.id
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            messagingViewModel.loadMessages(for: conversation.id ?? "")
            Task {
                await messagingViewModel.markConversationAsRead(conversation.id ?? "")
            }
        }
    }
    
    private func sendMessage() {
        guard let userId = authViewModel.currentUser?.id,
              let conversationId = conversation.id,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await messagingViewModel.sendMessage(
                content: messageText,
                conversationId: conversationId,
                senderId: userId
            )
            messageText = ""
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(isFromCurrentUser ? Color.blue : Color.secondary.opacity(0.2))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct EmptyConversationsView: View {
    var body: some View {
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
} 