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
            // Video Preview
            if !property.videoUrl.isEmpty,
               let videoURL = URL(string: property.videoUrl) {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 200)
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Property Details
            VStack(alignment: .leading, spacing: 8) {
                Text(property.title)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(property.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("$\(Int(property.price))/month")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Label("\(property.bedrooms)", systemImage: "bed.double")
                        Label(String(format: "%.1f", property.bathrooms), systemImage: "shower")
                        Label("\(Int(property.squareFootage))ft²", systemImage: "square")
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
        .padding()
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        .background(Color(UIColor.systemBackground))
        #elseif os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #endif
        .cornerRadius(16)
        .shadow(radius: 5)
    }
} 