import SwiftUI
import Core
import ViewModels

struct FavoritesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        NavigationView {
            Group {
                if appViewModel.propertyViewModel.isLoading {
                    ProgressView()
                } else if appViewModel.propertyViewModel.favoriteProperties.isEmpty {
                    EmptyFavoritesView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(appViewModel.propertyViewModel.favoriteProperties) { property in
                                PropertyCard(property: property)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Favorites")
        }
        .onAppear {
            if let userId = appViewModel.authViewModel.currentUser?.id {
                Task {
                    appViewModel.propertyViewModel.loadFavorites(for: userId)
                }
            }
        }
    }
}

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Properties you like will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(AppViewModel())
} 