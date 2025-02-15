import SwiftUI
import FirebaseAuth
import Core
import ViewModels

public struct ChatRoomView: View {
    let channel: ChatChannel
    @State private var newMessage: String = ""
    @EnvironmentObject private var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var messages: [ChatMessage] {
        viewModel.messages[channel.id ?? ""] ?? []
    }
    
    private var isSeller: Bool {
        channel.isSeller(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    private var otherUserId: String {
        channel.otherUserId(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    public var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageRow(message: message)
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
        .padding(.bottom, 20)
        .padding(.leading, 15)
        .navigationTitle(channel.chatTitle ?? (channel.otherUserName ?? (isSeller ? "Buyer" : "Seller")))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🔄 ChatRoomView: Setting up message subscription for channel \(channel.id ?? "")")
            if let channelId = channel.id {
                viewModel.observeMessages(in: channelId)
                Task {
                    try? await viewModel.markChannelAsRead(channelId)
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let channelId = channel.id else { return }
        
        Task {
            do {
                print("📤 ChatRoomView: Sending message in channel \(channelId)")
                try await viewModel.sendMessage(trimmed, in: channelId)
                newMessage = ""
            } catch {
                print("❌ ChatRoomView: Error sending message: \(error)")
            }
        }
    }
}

struct MessageRow: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            if message.isCurrentUser {
                Spacer()
                Text(message.text)
                    .padding(10)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
            } else {
                Text(message.text)
                    .padding(10)
                    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct ChatRoomView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatRoomView(channel: ChatChannel(
                buyerId: "buyer123",
                sellerId: "seller123",
                propertyId: "property123",
                videoId: "video123"
            ))
            .environmentObject(ChatViewModel())
        }
    }
} 
