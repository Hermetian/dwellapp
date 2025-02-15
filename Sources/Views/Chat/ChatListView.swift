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
                    List(chatViewModel.channels) { channel in
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
                                
                                if !channel.isRead && channel.lastSenderId != appViewModel.authViewModel.currentUser?.id {
                                    Spacer()
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 10, height: 10)
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