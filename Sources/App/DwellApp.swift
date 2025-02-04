import SwiftUI
import FirebaseCore
import ViewModels

@main
struct DwellApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            if appViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(appViewModel)
            } else {
                SignUpView()
                    .environmentObject(appViewModel)
            }
        }
    }
} 