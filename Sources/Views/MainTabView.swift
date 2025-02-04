import SwiftUI
import ViewModels

struct MainTabView: View {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some View {
        TabView {
            NavigationView {
                FeedView()
            }
            .tabItem {
                Label("Feed", systemImage: "house.fill")
            }
            
            NavigationView {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            NavigationView {
                UploadPropertyView()
            }
            .tabItem {
                Label("Upload", systemImage: "plus.square.fill")
            }
            
            NavigationView {
                MessagingView()
            }
            .tabItem {
                Label("Messages", systemImage: "message.fill")
            }
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .environmentObject(appViewModel)
    }
}

#Preview {
    MainTabView()
} 