import SwiftUI
import FirebaseCore
import ViewModels
import Views

@main
struct DwellApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            if appViewModel.authViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(appViewModel)
            } else {
                AuthView()
                    .environmentObject(appViewModel)
            }
        }
    }
} 