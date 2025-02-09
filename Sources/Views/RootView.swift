import SwiftUI
import ViewModels

public struct RootView: View {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @ObservedObject private var authViewModel: AuthViewModel
    
    public var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(appViewModel)
                    .environmentObject(chatViewModel)
                    .transition(.opacity)
            } else {
                AuthView()
                    .environmentObject(appViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: authViewModel.isAuthenticated)
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            print("🔄 RootView detected auth change: \(isAuthenticated)")
        }
    }
    
    public init() {
        let appVM = AppViewModel()
        self._appViewModel = StateObject(wrappedValue: appVM)
        self._authViewModel = ObservedObject(wrappedValue: appVM.authViewModel)
    }
}

#Preview {
    RootView()
} 
