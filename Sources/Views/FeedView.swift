import SwiftUI
import AVKit

struct FeedView: View {
    @StateObject private var propertyViewModel = PropertyViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(propertyViewModel.properties) { property in
                    PropertyCard(
                        property: property,
                        onLike: {
                            if let userId = propertyViewModel.currentUserId {
                                Task {
                                    await propertyViewModel.toggleFavorite(propertyId: property.id ?? "", userId: userId)
                                }
                            }
                        },
                        onShare: {
                            // Share functionality
                        },
                        onContact: {
                            // Contact functionality
                        }
                    )
                }
                
                if propertyViewModel.hasMoreProperties {
                    ProgressView()
                        .onAppear {
                            propertyViewModel.loadProperties()
                        }
                }
            }
            .padding()
        }
        .navigationTitle("DwellApp")
        .onAppear {
            propertyViewModel.loadProperties()
        }
        .refreshable {
            propertyViewModel.resetProperties()
        }
    }
}

#Preview {
    NavigationView {
        FeedView()
    }
} 