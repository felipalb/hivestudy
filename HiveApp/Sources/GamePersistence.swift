import Foundation
import HiveEngine

/// A full snapshot of an in-progress match, enough to restore it byte-for-byte
/// after the app is killed. Everything here is a pure `Codable` value type.
struct SavedGame: Codable {
    var options: GameOptions
    var state: GameState
    var history: [GameState]
}

/// Persists the current match so a player never loses their moves when the app
/// is closed. The game is (re)written after *every* ply; it's cleared only when
/// a game ends or the player explicitly leaves. See CLAUDE.md → "Persistence".
enum GamePersistence {
    private static let key = "hive.savedGame.v1"
    private static let defaults = UserDefaults.standard

    /// Write the snapshot. Called after each move (cheap: a few KB of JSON).
    static func save(_ saved: SavedGame) {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: key)
    }

    /// Load a resumable match, if one exists. Returns `nil` when there is nothing
    /// to resume — no save, an unreadable save, an empty board, or a finished game.
    static func load() -> SavedGame? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.state.result == .ongoing,
              saved.state.board.tileCount > 0
        else { return nil }
        return saved
    }

    /// Forget the saved match (game over, or the player left).
    static func clear() {
        defaults.removeObject(forKey: key)
    }
}
