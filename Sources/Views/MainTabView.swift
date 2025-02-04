import SwiftUI

struct MainTabView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab = 0
    @State private var showUploadProperty = false
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
        TabView(selection: $selectedTab) {
                    // Feed
            NavigationView {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(0..<10) { _ in
                                    PropertyDetailView(
                                        property: Property(
                                            managerId: "123",
                                            title: "Sample Property",
                                            description: "A beautiful property",
                                            price: 500000,
                                            address: "123 Main St",
                                            videoUrl: "https://example.com/video.mp4",
                                            bedrooms: 3,
                                            bathrooms: 2,
                                            squareFootage: 1500,
                                            availableFrom: Date()
                                        ),
                                        userId: authViewModel.currentUser?.id ?? ""
                                    )
                                }
                            }
                        }
                        .navigationTitle("DwellApp")
            }
            .tabItem {
                Label("Feed", systemImage: "house.fill")
            }
            .tag(0)
            
                    // Search
                SearchView()
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
            
                    // Upload
            Color.clear
                .tabItem {
                            Label("Upload", systemImage: "plus.circle.fill")
                }
                .tag(2)
            
                    // Favorites
                FavoritesView()
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(3)
            
                    // Profile
                ProfileView()
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(4)
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == 2 {
                showUploadProperty = true
                        selectedTab = 0
            }
        }
        .sheet(isPresented: $showUploadProperty) {
                UploadPropertyView()
                }
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    MainTabView()
} 