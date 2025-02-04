import SwiftUI

struct RootView: View {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some View {
        Group {
            if !appViewModel.authViewModel.isAuthenticated {
                AuthView(viewModel: appViewModel.authViewModel)
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
