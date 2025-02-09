import SwiftUI
import Core
import ViewModels

struct PropertyRowView: View {
    let property: Property
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleAvailability: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                Text(property.title)
                    .font(.headline)
                    .foregroundColor(property.isAvailable ? .primary : .gray)
                
                Text(property.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Label("\(property.videoIds.count) videos", systemImage: "video")
                        .font(.caption)
                    
                    Spacer()
                    
                    if !property.isAvailable {
                        Text("Unavailable")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text(property.price.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .bold()
                }
                .foregroundColor(.gray)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onToggleAvailability) {
                Label(property.isAvailable ? "Mark Unavailable" : "Mark Available",
                      systemImage: property.isAvailable ? "eye.slash" : "eye")
            }
            .tint(property.isAvailable ? .orange : .green)
        }
    }
} 