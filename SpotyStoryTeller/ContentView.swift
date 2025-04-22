import SwiftUI
import SpotifyWebAPI
import Combine
import MarkdownUI

struct ContentView: View {
    // Access the auth manager from the environment
    @EnvironmentObject var authManager: SpotifyAuthManager
    
    // Local cancellables storage for this view
    @State private var viewCancellables = Set<AnyCancellable>()
    
    // State to track current volume
    @State private var volume: Double = 0.5
    
    // State to track current playback information
    @State private var currentTrack: CurrentlyPlayingContext?
    @State private var isPlaying: Bool = false
    @State private var albumArtURL: URL?
    @State private var albumName: String = ""
    
    // Timer for updating playback info
    @State private var timer: Timer?
    
    // Add OpenAI manager
    private let openAIManager = OpenAIManager(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "")
    
    // AI-generated content
    @State private var trackInsights: String = ""
    @State private var isLoadingInsights: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Display different content based on authentication state
            if authManager.isAuthorized {
                // User is logged in - show controls
                connectedView
            } else {
                // User is not logged in - show login button
                disconnectedView
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
        .onAppear {
            if authManager.isAuthorized {
                // Fetch current track when view appears
                fetchCurrentPlayback()

                // Set up timer to refresh every 5 seconds
                timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                    fetchCurrentPlayback()
                }
            }
        }
        .onDisappear {
            // Invalidate timer when view disappears
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: authManager.isAuthorized) { isAuthorized in
            if isAuthorized {
                fetchCurrentPlayback()

                // Set up timer to refresh every 5 seconds
                timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                    fetchCurrentPlayback()
                }
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    // View shown when user is connected to Spotify
    var connectedView: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 10) {
                    if let currentTrack = currentTrack, let item = currentTrack.item {
                        // Album artwork if available
                        if let albumArtURL = albumArtURL {
                            AsyncImage(url: albumArtURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 200, height: 200)
                                        .cornerRadius(6)
                                case .failure:
                                    Image(systemName: "music.note")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .padding(30)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(.bottom, 5)
                        } else {
                            Image(systemName: "music.note")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .padding(30)
                        }

                        // Track title
                        Text(item.name!)
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        // Artist name - Extract from the JSON data we already have
                        if let artistsString = extractArtistsString(from: item) {
                            Text(artistsString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Album name
                        if !albumName.isEmpty {
                            Text(albumName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Additional track details
                        HStack(spacing: 15) {
                            // Duration
                            if let durationMs = item.durationMS {
                                Label(formatDuration(durationMs), systemImage: "clock")
                                    .font(.caption)
                            }
                        }
                        .padding(.top, 2)
                    } else {
                        Text("No track currently playing")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .frame(maxWidth: 200, alignment: .leading)
                .layoutPriority(1)
                // Insights section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Song Insights")
                            .font(.headline)

                        if isLoadingInsights {
                            ProgressView()
                                .padding(.leading, 5)
                        } else {
                            Button(action: {
                                if let currentTrack = currentTrack, let item = currentTrack.item,
                                   let artistsString = extractArtistsString(from: item) {
                                    generateInsights(track: item.name!, artist: artistsString, album: albumName)
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ScrollView {
                        Markdown(.init(trackInsights.isEmpty
                            ? "Click the refresh button to get AI insights about this track."
                            : trackInsights))
                        .font(.body)
                        .padding(.vertical, 5)
                        
                    }
                    .frame(maxHeight: 400)
                }
                .font(.body)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity)
            
                

                

            // Controls section with gray background
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    VStack(spacing: 10) {
                        HStack(spacing: 30) {
                            Button(action: { skipToPrevious() }) {
                                Image(systemName: "backward.fill").font(.title)
                            }
                            Button(action: { togglePlayPause() }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.title)
                            }
                            Button(action: { skipToNext() }) {
                                Image(systemName: "forward.fill").font(.title)
                            }
                        }
                        .padding()

                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $volume, in: 0...1, onEditingChanged: { editing in
                                if !editing {
                                    setVolume(volume: Int(volume * 100))
                                }
                            })
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                )
                .frame(height: 120)

            // Bottom right connection info and logout
            HStack {
                Spacer()
                Text("Connected to Spotify")
                    .foregroundColor(.green)
                Button("Logout") {
                    self.authManager.authorize()
                    
                }
                .padding(.leading, 10)
            }
        }
        .padding()
    }
    
    // View shown when user is not connected
    var disconnectedView: some View {
        VStack(spacing: 15) {
            Text("Not connected to Spotify")
                .font(.headline)
            
            Text("Connect to Spotify to control playback")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                authManager.authorize()
            }) {
                Text("Connect to Spotify")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    // Format duration from milliseconds to mm:ss
    func formatDuration(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Helper to extract artists names from item
    func extractArtistsString(from item: PlaylistItem) -> String? {
        if let json = try? JSONEncoder().encode(item),
           let dict = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
           let artists = dict["artists"] as? [[String: Any]] {
            
            let artistNames = artists.compactMap { $0["name"] as? String }
            return artistNames.joined(separator: ", ")
        }
        return nil
    }
    
    // Generate AI insights with caching using DatabaseManager
    private func generateInsights(track: String, artist: String, album: String) {
        if let cached = DatabaseManager.shared.loadInsight(track: track, artist: artist, album: album) {
            self.trackInsights = cached
            return
        }

        isLoadingInsights = true
        trackInsights = "Generating insights..."

        Task {
            do {
                let insight = try await openAIManager.generateTrackInsights(
                    track: track,
                    artist: artist,
                    album: album
                )

                DispatchQueue.main.async {
                    self.trackInsights = insight
                    self.isLoadingInsights = false
                    DatabaseManager.shared.saveInsight(track: track, artist: artist, album: album, insight: insight)
                }
            } catch {
                DispatchQueue.main.async {
                    self.trackInsights = "Error generating insights: \(error.localizedDescription)"
                    self.isLoadingInsights = false
                }
            }
        }
    }
    
    // MARK: - Spotify Data Functions
    
    // Fetch current playback information
    func fetchCurrentPlayback() {
        let previousTrackId = currentTrack?.item?.id
        
        authManager.spotifyAPI.currentPlayback()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error getting playback state: \(error)")
                    }
                },
                receiveValue: { playback in
                    self.currentTrack = playback
                    self.isPlaying = playback?.isPlaying ?? false
                    
                    if let newItem = playback?.item, previousTrackId != newItem.id {
                        self.trackInsights = ""
                        
                        // Auto-fetch insights for the new track
                        if let artistsString = self.extractArtistsString(from: newItem) {
                            let album: String
                            if let albumDict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(newItem)) as? [String: Any],
                               let albumInfo = albumDict["album"] as? [String: Any],
                               let name = albumInfo["name"] as? String,
                               let date = albumInfo["release_date"] as? String {
                                album = "from the album '\(name)' (\(date))"
                            } else {
                                album = ""
                            }
                            // Automatically generate insights when track changes
                            self.generateInsights(
                                track: newItem.name!,
                                artist: artistsString,
                                album: album,
                            )
                        }
                    }
                    
                    // Update volume if available
                    if let deviceVolume = playback?.device.volumePercent {
                        self.volume = Double(deviceVolume) / 100.0
                    }
                    
                    
                    // Extract album information
                    if let item = playback?.item {
                        // Use reflection or other methods to extract images
                        // This is a workaround for the type casting issues
                        if let json = try? JSONEncoder().encode(item),
                           let dict = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
                            
                            // Extract album info for tracks
                            if let album = dict["album"] as? [String: Any] {
                                
                                // Album name
                                if let name = album["name"] as? String, let date = album["release_date"] as? String {
                                    self.albumName = name + " " + date
                                }
                                
                                // Album art
                                if let images = album["images"] as? [[String: Any]], !images.isEmpty {
                                    // Use medium size if available
                                    let imageData = images.count > 1 ? images[1] : images[0]
                                    if let urlString = imageData["url"] as? String,
                                       let url = URL(string: urlString) {
                                        self.albumArtURL = url
                                    }
                                }
                            }
                            // Extract images for podcast episodes
                            else if let images = dict["images"] as? [[String: Any]], !images.isEmpty {
                                if let urlString = images[0]["url"] as? String,
                                   let url = URL(string: urlString) {
                                    self.albumArtURL = url
                                }
                                // Podcast name might be in show.name
                                if let show = dict["show"] as? [String: Any],
                                   let name = show["name"] as? String {
                                    self.albumName = name
                                }
                            } else {
                                self.albumArtURL = nil
                                self.albumName = ""
                            }
                        }
                    } else {
                        self.albumArtURL = nil
                        self.albumName = ""
                    }
                }
            )
            .store(in: &viewCancellables)
    }
    
    // MARK: - Spotify Control Functions
    
    func togglePlayPause() {
        if isPlaying {
            // If playing, pause
            authManager.spotifyAPI.pausePlayback()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Error pausing: \(error)")
                        }
                    },
                    receiveValue: { _ in
                        print("Paused playback")
                        self.isPlaying = false
                        // Refresh current playback after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.fetchCurrentPlayback()
                        }
                    }
                )
                .store(in: &viewCancellables)
        } else {
            // If paused, resume
            authManager.spotifyAPI.resumePlayback()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Error resuming: \(error)")
                        }
                    },
                    receiveValue: { _ in
                        print("Resumed playback")
                        self.isPlaying = true
                        // Refresh current playback after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.fetchCurrentPlayback()
                        }
                    }
                )
                .store(in: &viewCancellables)
        }
    }
    
    func skipToPrevious() {
        authManager.spotifyAPI.skipToPrevious()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error skipping to previous: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("Skipped to previous track")
                    // Refresh current playback after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.fetchCurrentPlayback()
                    }
                }
            )
            .store(in: &viewCancellables)
    }
    
    func skipToNext() {
        authManager.spotifyAPI.skipToNext()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error skipping to next: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("Skipped to next track")
                    // Refresh current playback after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.fetchCurrentPlayback()
                    }
                }
            )
            .store(in: &viewCancellables)
    }
    
    func setVolume(volume: Int) {
        authManager.spotifyAPI.setVolume(to: volume)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error setting volume: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("Set volume to \(volume)%")
                }
            )
            .store(in: &viewCancellables)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SpotifyAuthManager())
    }
}
