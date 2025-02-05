import SwiftUI
import AVKit
import Models
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct PropertyCard: View {
    let property: Property
    var onLike: (() -> Void)?
    var onShare: (() -> Void)?
    var onContact: (() -> Void)?
    
    public init(
        property: Property,
        onLike: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onContact: (() -> Void)? = nil
    ) {
        self.property = property
        self.onLike = onLike
        self.onShare = onShare
        self.onContact = onContact
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Property Image
            AsyncImage(url: URL(string: property.thumbnailUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Property Details
            VStack(alignment: .leading, spacing: 8) {
                Text(property.title)
                    .font(.headline)
                
                Text(property.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("$\(Int(property.price))/month")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Label("\(property.bedrooms)", systemImage: "bed.double.fill")
                        Label(String(format: "%.1f", property.bathrooms), systemImage: "shower.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            // Action Buttons
            if onLike != nil || onShare != nil || onContact != nil {
                HStack(spacing: 20) {
                    if let onLike = onLike {
                        Button(action: onLike) {
                            Image(systemName: "heart")
                        }
                    }
                    
                    if let onShare = onShare {
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    
                    if let onContact = onContact {
                        Button(action: onContact) {
                            Image(systemName: "message")
                        }
                    }
                    
                    Spacer()
                }
                .font(.title3)
                .foregroundColor(.blue)
                .padding(.horizontal, 4)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

#Preview {
    PropertyCard(property: Property(
        managerId: "123",
        title: "Sample Property",
        description: "A beautiful property",
        price: 2000,
        address: "123 Main St",
        videoUrl: "",
        bedrooms: 2,
        bathrooms: 2,
        squareFootage: 1000,
        availableFrom: Date(),
        type: "Apartment",
        userId: "123"
    ))
} 