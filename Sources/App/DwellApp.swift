import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseCrashlytics
import ViewModels
import Views
import Logging
import GoogleCloudLogging

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
        
        // Set up Google Cloud Logging as the logging backend
        LoggingSystem.bootstrap(GoogleCloudLogHandler.init)
        do {
            let keyURL = Bundle.main.url(forResource: "ServiceAccountKey", withExtension: "json")!
            try GoogleCloudLogHandler.setup(serviceAccountCredentials: keyURL, clientId: UIDevice.current.identifierForVendor)
        } catch {
            print("Failed to setup Cloud Logging: \(error)")
            Crashlytics.crashlytics().record(error: error)
        }
        
        let logger = Logger(label: "DwellApp")
        logger.info("App launched and Cloud Logging initialized")
        Crashlytics.crashlytics().log("App launched and Cloud Logging initialized")
        
        print("🔥 Firebase configured with debug logging enabled")
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle universal links
        if let incomingURL = userActivity.webpageURL {
            Crashlytics.crashlytics().log("Processing universal link: \(incomingURL)")
            return handleIncomingLink(incomingURL)
        }
        return false
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        Crashlytics.crashlytics().log("Processing URL open: \(url)")
        return handleIncomingLink(url)
    }
    
    private func handleIncomingLink(_ url: URL) -> Bool {
        // Check if the link is an email sign-in link
        if Auth.auth().isSignIn(withEmailLink: url.absoluteString) {
            if let email = UserDefaults.standard.string(forKey: "emailForSignIn") {
                Crashlytics.crashlytics().log("Processing email sign-in link for: \(email)")
                // Post notification to handle sign in
                NotificationCenter.default.post(
                    name: Notification.Name("HandleEmailSignInLink"),
                    object: nil,
                    userInfo: ["email": email, "link": url.absoluteString]
                )
                return true
            }
            Crashlytics.crashlytics().log("Email sign-in link received but no email found in UserDefaults")
        }
        return false
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        Crashlytics.crashlytics().log("App entering background - uploading logs")
        GoogleCloudLogHandler.upload()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Crashlytics.crashlytics().log("App terminating - uploading logs")
        GoogleCloudLogHandler.upload()
    }
} 
