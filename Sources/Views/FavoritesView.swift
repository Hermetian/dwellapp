import SwiftUI

struct FavoritesView: View {
    @StateObject private var propertyViewModel = PropertyViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if propertyViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if propertyViewModel.favoriteProperties.isEmpty {
                EmptyFavoritesView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(propertyViewModel.favoriteProperties) { property in
                            NavigationLink(destination: PropertyDetailView(property: property, userId: authViewModel.currentUser?.id ?? "")) {
                                PropertyListItem(property: property)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Favorites")
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                propertyViewModel.loadFavorites(for: userId)
            }
        }
    }
}

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundColor(.red.opacity(0.3))
            
            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Properties you like will appear here")
                .foregroundColor(.gray)
            
            NavigationLink(destination: SearchView()) {
                Text("Browse Properties")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        FavoritesView()
    }
} 