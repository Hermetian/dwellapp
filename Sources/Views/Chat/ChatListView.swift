import SwiftUI
import FirebaseAuth
import ViewModels
import Core

public struct ChatListView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.colorScheme) var colorScheme
    
    private func isChannelSeller(_ channel: ChatChannel) -> Bool {
        channel.isSeller(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    private func getOtherUserId(_ channel: ChatChannel) -> String {
        channel.otherUserId(currentUserId: appViewModel.authViewModel.currentUser?.id ?? "")
    }
    
    private func channelDisplayName(_ channel: ChatChannel) -> String {
        channel.otherUserName ?? (isChannelSeller(channel) ? "Buyer" : "Seller")
    }
    
    private func isPropertyFavorited(_ propertyId: String) -> Bool {
        appViewModel.propertyViewModel.favoriteProperties.contains { $0.id == propertyId }
    }
    
    private var sortedChannels: [ChatChannel] {
        chatViewModel.channels.sorted { channel1, channel2 in
            // First, sort by favorite status
            let isFavorite1 = isPropertyFavorited(channel1.propertyId)
            let isFavorite2 = isPropertyFavorited(channel2.propertyId)
            
            if isFavorite1 != isFavorite2 {
                return isFavorite1
            }
            
            // Then sort by timestamp
            let date1 = channel1.lastMessageTimestamp ?? channel1.serverTimestamp?.dateValue() ?? Date.distantPast
            let date2 = channel2.lastMessageTimestamp ?? channel2.serverTimestamp?.dateValue() ?? Date.distantPast
            return date1 > date2
        }
    }
    
    public var body: some View {
        NavigationView {
            Group {
                if chatViewModel.isLoading {
                    ProgressView("Loading chats...")
                        .onAppear {
                            print("⏳ ChatListView: Showing loading state")
                        }
                } else if chatViewModel.channels.isEmpty {
                    VStack(spacing: 16) {
                        Text("No chats yet")
                            .font(.headline)
                        Text("Start a chat from any property video")
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        print("ℹ️ ChatListView: No channels to display")
                    }
                } else {
                    List(sortedChannels) { channel in
                        NavigationLink(destination: ChatRoomView(channel: channel)) {
                            HStack {
                                Circle()
                                    .fill(isChannelSeller(channel) ? Color.blue : Color.green)
                                    .frame(width: 20, height: 20)
                                VStack(alignment: .leading) {
                                    Text(channelDisplayName(channel))
                                        .font(.headline)
                                    if let title = channel.chatTitle {
                                        Text(title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                    if let lastMessage = channel.lastMessage {
                                        Text(lastMessage)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    // Heart icon for favorite properties
                                    Button {
                                        if let userId = appViewModel.authViewModel.currentUser?.id {
                                            Task {
                                                try await appViewModel.propertyViewModel.toggleFavorite(
                                                    propertyId: channel.propertyId,
                                                    userId: userId
                                                )
                                            }
                                        }
                                    } label: {
                                        Image(systemName: isPropertyFavorited(channel.propertyId) ? "heart.fill" : "heart")
                                            .foregroundColor(isPropertyFavorited(channel.propertyId) ? .red : .gray)
                                    }
                                    
                                    // Unread message indicator
                                    if !channel.isRead && channel.lastSenderId != appViewModel.authViewModel.currentUser?.id {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .onAppear {
                        print("📱 ChatListView: Displaying \(chatViewModel.channels.count) channels")
                    }
                }
            }
            .navigationTitle("Chats")
            .listStyle(InsetGroupedListStyle())
            .overlay(
                Group {
                    if let error = chatViewModel.error {
                        VStack {
                            Text("Error: \(error.localizedDescription)")
                                .foregroundColor(.red)
                                .padding()
                            Button("Retry") {
                                print("🔄 ChatListView: Retrying after error")
                                chatViewModel.clearError()
                                chatViewModel.setupSubscriptions()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                        .onAppear {
                            print("❌ ChatListView: Showing error - \(error.localizedDescription)")
                        }
                    }
                }
            )
        }
        .onAppear {
            print("🔄 ChatListView: View appeared, setting up subscriptions")
            chatViewModel.setupSubscriptions()
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView()
            .environmentObject(ChatViewModel())
            .environmentObject(AppViewModel())
    }
} 