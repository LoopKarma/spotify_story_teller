import Foundation
import DotEnv

struct Environment {
    static let shared = Environment()
    
    private let env: [String: String]
    
    private init() {
        if let dotEnvURL = Bundle.main.url(forResource: ".env", withExtension: nil) {
            do {
                try DotEnv.load(path: dotEnvURL.path)
                self.env = ProcessInfo.processInfo.environment
            } catch {
                print("Failed to load .env file: \(error)")
                self.env = [:]
            }
        } else {
            self.env = [:]
        }
    }
    
    func get(_ key: String) -> String? {
        return env[key] ?? ProcessInfo.processInfo.environment[key]
    }
    
    var spotifyClientId: String {
        return get("SPOTIFY_CLIENT_ID") ?? ""
    }
    
    var spotifyClientSecret: String {
        return get("SPOTIFY_CLIENT_SECRET") ?? ""
    }
    
    var openAIApiKey: String {
        return get("OPENAI_API_KEY") ?? ""
    }
}
