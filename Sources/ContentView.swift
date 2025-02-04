import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationView {
                FeedView()
            }
            .tabItem {
                Label("Feed", systemImage: "house.fill")
            }
            
            NavigationView {
                Text("Search")
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            NavigationView {
                Text("Upload")
            }
            .tabItem {
                Label("Upload", systemImage: "plus.circle.fill")
            }
            
            NavigationView {
                Text("Favorites")
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            
            NavigationView {
                Text("Profile")
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
    }
}

#Preview {
    ContentView()
} 