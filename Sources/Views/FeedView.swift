import SwiftUI
import Models
import ViewModels

struct FeedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(appViewModel.propertyViewModel.properties) { property in
                    PropertyCard(
                        property: property,
                        onLike: {
                            if let userId = appViewModel.authViewModel.currentUser?.id {
                                Task {
                                    await appViewModel.propertyViewModel.toggleFavorite(propertyId: property.id ?? "", userId: userId)
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
                
                if appViewModel.propertyViewModel.hasMoreProperties {
                    ProgressView()
                        .onAppear {
                            Task {
                                await appViewModel.propertyViewModel.loadProperties()
                            }
                        }
                }
            }
            .padding()
        }
        .navigationTitle("DwellApp")
        .onAppear {
            Task {
                await appViewModel.propertyViewModel.loadProperties()
            }
        }
        .refreshable {
            Task {
                await appViewModel.propertyViewModel.resetProperties()
            }
        }
    }
}

#Preview {
    NavigationView {
        FeedView()
            .environmentObject(AppViewModel())
    }
} 