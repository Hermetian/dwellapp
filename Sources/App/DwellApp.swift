import SwiftUI
import FirebaseCore
import FirebaseAuth
import ViewModels
import Views

@main
struct DwellApp: App {
    // Register app delegate for Firebase setup and deep linking
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Enable Firebase debug loggingx
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        
        // Configure Firebase
        FirebaseApp.configure()
        
        print("🔥 Firebase configured with debug logging enabled")
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle universal links
        if let incomingURL = userActivity.webpageURL {
            return handleIncomingLink(incomingURL)
        }
        return false
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return handleIncomingLink(url)
    }
    
    private func handleIncomingLink(_ url: URL) -> Bool {
        // Check if the link is an email sign-in link
        if Auth.auth().isSignIn(withEmailLink: url.absoluteString) {
            if let email = UserDefaults.standard.string(forKey: "emailForSignIn") {
                // Post notification to handle sign in
                NotificationCenter.default.post(
                    name: Notification.Name("HandleEmailSignInLink"),
                    object: nil,
                    userInfo: ["email": email, "link": url.absoluteString]
                )
                return true
            }
        }
        return false
    }
} 
