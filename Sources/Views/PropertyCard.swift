import SwiftUI
import AVKit

struct PropertyCard: View {
    let property: Property
    var onLike: (() -> Void)?
    var onShare: (() -> Void)?
    var onContact: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Property Video/Image
            AsyncImage(url: URL(string: property.thumbnailUrl ?? property.videoUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color.gray.opacity(0.3)
                    ProgressView()
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Property Details
            VStack(alignment: .leading, spacing: 8) {
                Text(property.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("$\(Int(property.price))/month")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("\(property.bedrooms) bed, \(property.bathrooms) bath · \(Int(property.squareFootage)) sqft")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(property.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Action Buttons
            HStack {
                Button(action: { onLike?() }) {
                    Label("Like", systemImage: "heart")
                }
                
                Spacer()
                
                Button(action: { onShare?() }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Spacer()
                
                Button(action: { onContact?() }) {
                    Label("Contact", systemImage: "message")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
} 