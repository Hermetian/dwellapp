import SwiftUI

struct ChatRoomView: View {
    let channel: ChatChannel
    @State private var newMessage: String = ""
    @EnvironmentObject var chatManager: ChatManager
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(channel.messages) { message in
                        MessageRow(message: message)
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                TextField("Enter message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: sendMessage) {
                    Text("Send")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle(channel.otherUser)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatManager.sendMessage(trimmed, in: channel.id)
        newMessage = ""
    }
}

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.sender == "CurrentUser" {
                Spacer()
                Text(message.content)
                    .padding(10)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
            } else {
                Text(message.content)
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
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
                id: UUID(),
                otherUser: "John Doe",
                propertySummary: "Sample Property",
                isSeller: false,
                videoId: UUID(),
                propertyId: UUID(),
                messages: []
            ))
            .environmentObject(ChatManager())
        }
    }
} 