import Foundation
import SpotifyWebAPI
import Combine
import AppKit
import Swifter

class SpotifyAuthManager: ObservableObject {
    // Create a Spotify API instance with your credentials
    let spotifyAPI = SpotifyAPI(
        authorizationManager: AuthorizationCodeFlowManager(
            clientId: Environment.shared.spotifyClientId,
            clientSecret: Environment.shared.spotifyClientSecret
        )
    )
    
    // Store for cancellable subscriptions
    private var cancellables: Set<AnyCancellable> = []
    
    // HTTP server
    private var server: HttpServer?
    
    // Published property that the UI can observe
    @Published var isAuthorized = false
    
    init() {
        // Check if we already have a valid access token
        if spotifyAPI.authorizationManager.accessToken != nil {
            isAuthorized = true
        }
    }
    
    // Start the authorization process
    func authorize() {
        // Start the local web server to receive the callback
        startWebServer()
        
        // The redirect URI you configured in your Spotify app
        let redirectURI = URL(string: "http://127.0.0.1:8888/callback")!
        
        // Create the authorization URL with the necessary scopes
        let authorizationURL = spotifyAPI.authorizationManager.makeAuthorizationURL(
            redirectURI: redirectURI,
            showDialog: true,
            scopes: [
                .userReadPlaybackState,
                .userModifyPlaybackState,
                .userReadCurrentlyPlaying
            ]
        )!
        
        // Open the authorization URL in the default browser
        NSWorkspace.shared.open(authorizationURL)
    }
    
    // Start the local web server to receive the callback
    private func startWebServer() {
        server = HttpServer()
        
        // Add handler for the callback
        server?["/callback"] = { request in
            // Construct the full callback URL
            var fullURLString = "http://127.0.0.1:8888/callback"
            
            // Fixed: Check if queryParams exists and isn't empty
            let queryParams = request.queryParams
            if !queryParams.isEmpty {
                fullURLString += "?"
                fullURLString += queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
            }
            
            if let fullURL = URL(string: fullURLString) {
                // Process the callback
                self.processAuthCallback(url: fullURL)
                
                // Return success page
                let html = """
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Spotify Authorization Successful</title>
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; text-align: center; padding-top: 50px; }
                        h1 { color: #1DB954; }
                    </style>
                </head>
                <body>
                    <h1>Successfully Connected to Spotify!</h1>
                    <p>You can close this window and return to the application.</p>
                </body>
                </html>
                """
                
                return .ok(.html(html))
            }
            
            return .notFound
        }
        
        // Start the server
        do {
            try server?.start(8888, forceIPv4: true)
            print("Web server started successfully on port 8888")
        } catch {
            print("Failed to start web server: \(error)")
        }
    }
    
    // Process the authorization callback
    func processAuthCallback(url: URL) {
        // Exchange the authorization code for access and refresh tokens
        spotifyAPI.authorizationManager.requestAccessAndRefreshTokens(
            redirectURIWithQuery: url,
            state: nil
        )
        .sink(receiveCompletion: { [weak self] completion in
            if case .failure(let error) = completion {
                print("Authorization error: \(error)")
            }
            
            // Stop the web server as it's no longer needed
            self?.stopWebServer()
        }, receiveValue: { [weak self] _ in
            guard let self = self else { return }
            
            // Update on the main thread
            DispatchQueue.main.async {
                self.isAuthorized = true
                print("Successfully authorized with Spotify")
                
                // Save tokens for later use
                self.saveTokens()
            }
            
            // Stop the web server as it's no longer needed
            // Fixed: Remove the optional chaining
            self.stopWebServer()
        })
        .store(in: &cancellables)
    }
    
    // Stop the web server
    private func stopWebServer() {
        server?.stop()
        server = nil
        print("Web server stopped")
    }
    
    // Helper method to save tokens to UserDefaults
    private func saveTokens() {
        // This is optional but helpful for persisting the session
        if let accessToken = spotifyAPI.authorizationManager.accessToken,
           let refreshToken = spotifyAPI.authorizationManager.refreshToken,
           let expirationDate = spotifyAPI.authorizationManager.expirationDate {
            
            UserDefaults.standard.set(accessToken, forKey: "spotifyAccessToken")
            UserDefaults.standard.set(refreshToken, forKey: "spotifyRefreshToken")
            UserDefaults.standard.set(expirationDate, forKey: "spotifyExpirationDate")
        }
    }
}
