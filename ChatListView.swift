import SwiftUI

struct ChatChannel: Identifiable {
    let id: UUID
    let otherUser: String
    let propertySummary: String?
    let isSeller: Bool
    let videoId: UUID
    let propertyId: UUID
    var messages: [Message]
}

struct Message: Identifiable {
    let id: UUID
    let sender: String
    let content: String
    let timestamp: Date
}

struct ChatListView: View {
    @EnvironmentObject var chatManager: ChatManager
    
    var body: some View {
        NavigationView {
            List(chatManager.channels) { channel in
                NavigationLink(destination: ChatRoomView(channel: channel)) {
                    HStack {
                        Circle()
                            .fill(channel.isSeller ? Color.blue : Color.green)
                            .frame(width: 20, height: 20)
                        VStack(alignment: .leading) {
                            Text(channel.otherUser)
                                .font(.headline)
                            if let summary = channel.propertySummary {
                                Text(summary)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Chats")
            .listStyle(InsetGroupedListStyle())
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView()
            .environmentObject(ChatManager())
    }
} 