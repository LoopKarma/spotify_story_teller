import SQLite
import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?
    private let insightsTable = Table("TrackInsights")
    private let trackCol = Expression<String>("track")
    private let artistCol = Expression<String>("artist")
    private let albumCol = Expression<String>("album")
    private let insightCol = Expression<String>("insight")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        let dbPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SpotifyInsights.sqlite")
        print("Database located at: \(dbPath.path)")
        do {
            try FileManager.default.createDirectory(at: dbPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            db = try Connection(dbPath.path)

            try db?.run(insightsTable.create(ifNotExists: true) { t in
                t.column(trackCol)
                t.column(artistCol)
                t.column(albumCol)
                t.column(insightCol)
                t.primaryKey(trackCol, artistCol, albumCol)
            })
        } catch {
            print("DB setup failed: \(error)")
        }
    }

    func loadInsight(track: String, artist: String, album: String) -> String? {
        guard let db = db else { return nil }
        do {
            let query = insightsTable.filter(trackCol == track && artistCol == artist && albumCol == album)
            if let row = try db.pluck(query) {
                return row[insightCol]
            }
        } catch {
            print("Error querying insights: \(error)")
        }
        return nil
    }

    func saveInsight(track: String, artist: String, album: String, insight: String) {
        guard let db = db else { return }
        do {
            let insert = insightsTable.insert(or: .replace,
                trackCol <- track,
                artistCol <- artist,
                albumCol <- album,
                insightCol <- insight
            )
            try db.run(insert)
        } catch {
            print("Error saving insight: \(error)")
        }
    }
}
