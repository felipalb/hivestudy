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

/// Persistent player preferences for game setup and difficulty.
enum UserPreferences {
    private static let defaults = UserDefaults.standard
    private static let difficultyKey = "hive.preference.difficulty"
    private static let tournamentKey = "hive.preference.tournament"
    private static let colorChoiceKey = "hive.preference.colorChoice"

    /// The player's configured difficulty for regular matches (Fácil, Médio, Difícil).
    /// Tutorial and Campaign ignore this setting and ALWAYS use the didactic/peaceful engine.
    static var difficulty: HiveAI.Difficulty {
        get {
            guard let raw = defaults.string(forKey: difficultyKey),
                  let diff = HiveAI.Difficulty(rawValue: raw),
                  diff == .easy || diff == .medium || diff == .hard
            else { return .medium }
            return diff
        }
        set {
            defaults.set(newValue.rawValue, forKey: difficultyKey)
        }
    }

    static var tournamentOpening: Bool {
        get { defaults.bool(forKey: tournamentKey) }
        set { defaults.set(newValue, forKey: tournamentKey) }
    }

    static var colorChoice: GameOptions.ColorChoice {
        get {
            guard let raw = defaults.string(forKey: colorChoiceKey),
                  let choice = GameOptions.ColorChoice(rawValue: raw)
            else { return .random }
            return choice
        }
        set {
            defaults.set(newValue.rawValue, forKey: colorChoiceKey)
        }
    }

    /// Returns a GameOptions struct populated with the player's saved preferences.
    static func defaultOptions() -> GameOptions {
        var opts = GameOptions()
        opts.mode = .vsAI
        opts.difficulty = difficulty
        opts.tournamentOpening = tournamentOpening
        opts.colorChoice = colorChoice
        return opts
    }
}
