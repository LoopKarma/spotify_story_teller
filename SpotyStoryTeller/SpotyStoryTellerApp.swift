
import SwiftUI

@main
struct SpotyStoryTellerApp: App {
    // This connects the AppDelegate to your SwiftUI app
   @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.spotifyAuthManager)
        }
    }
}
