import SwiftUI
import ViewModels

struct RootView: View {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some View {
        Group {
            if !appViewModel.authViewModel.isAuthenticated {
                AuthView()
            } else {
                MainTabView()
            }
        }
        .environmentObject(appViewModel)
    }
}

#Preview {
    RootView()
} 
