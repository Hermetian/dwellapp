import SwiftUI
import ViewModels

public struct MainTabView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    public var body: some View {
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
    }
    
    public init() {}
}

#Preview {
    MainTabView()
} 