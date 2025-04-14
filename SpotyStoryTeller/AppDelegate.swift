import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let spotifyAuthManager = SpotifyAuthManager()
    
    // This method gets called when your app receives a URL
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            // Process the callback URL from Spotify
            spotifyAuthManager.processAuthCallback(url: url)
        }
    }

}
