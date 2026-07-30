import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// Options chosen when starting a game. `Codable` so a match can be cached.
struct GameOptions: Equatable, Codable {
    enum Mode: String, CaseIterable, Identifiable, Codable { case vsAI, twoPlayer
        var id: String { rawValue }
        var label: String { self == .vsAI ? "Vs. Computer" : "Two Players" }
    }
    var mode: Mode = .vsAI
    var humanColor: PlayerColor = .white          // in vs-AI, the side the human plays
    var difficulty: HiveAI.Difficulty = .medium
    var tournamentOpening: Bool = false

    var aiColor: PlayerColor { humanColor.opponent }

    /// Preset for the "Play Tutorial" action: vs. a deliberately very weak,
    /// forgiving bot, human plays White, no tournament restriction.
    static var tutorial: GameOptions {
        var options = GameOptions()
        options.mode = .vsAI
        options.humanColor = .white
        options.difficulty = .megaEasy
        return options
    }
}

/// Owns the game state and drives all interaction. `@MainActor` because it feeds
/// SwiftUI directly; the AI search runs off the main actor and hops back to apply.
@MainActor
@Observable
final class GameController {
    private(set) var state: GameState
    private(set) var history: [GameState] = []
    private(set) var targets: Set<Hex> = []
    private(set) var isThinking = false
    var options: GameOptions

    /// A match found in the cache at launch, awaiting the player's "Continue /
    /// Leave" choice. While non-nil the board shows a fresh game and the AI is
    /// held back until the player decides.
    private(set) var pendingResume: SavedGame?

    /// What the player currently has "picked up".
    enum Selection: Equatable {
        case none
        case hand(Bug, PlayerColor)
        case board(pieceID: Int, hex: Hex)
    }
    private(set) var selection: Selection = .none

    init(options: GameOptions = GameOptions()) {
        self.options = options
        self.state = GameState(config: Self.config(for: options))

        if ProcessInfo.processInfo.environment["HIVE_DEMO"] == "1" {
            loadDemo()
            scheduleAIIfNeeded()
            return
        }

        // A match interrupted by the app being killed is offered back to the
        // player ("Continue Game / Leave Game") before anything else runs.
        if let saved = GamePersistence.load() {
            pendingResume = saved
            return
        }

        scheduleAIIfNeeded()
    }

    /// Seeds an illustrative mid-game position with a piece pre-selected, used
    /// for screenshots/previews (enabled via the HIVE_DEMO environment variable).
    private func loadDemo() {
        options.mode = .twoPlayer
        var s = GameState()
        var rng = DemoRNG(seed: 11)
        var plies = 0
        while plies < 14 && s.result == .ongoing {
            let moves = s.legalMoves()
            s.apply(moves[Int(rng.next() % UInt64(moves.count))])
            plies += 1
        }
        state = s
        guard s.current == .white else { return }
        for hex in s.board.occupiedCells {
            guard let top = s.board.topPiece(hex), top.color == .white else { continue }
            let dests = MoveGenerator.destinations(for: top.id, in: s)
            if !dests.isEmpty {
                selection = .board(pieceID: top.id, hex: hex)
                targets = Set(dests)
                break
            }
        }
    }

    // MARK: Derived

    var result: GameResult { state.result }
    var current: PlayerColor { state.current }
    var canUndo: Bool { !history.isEmpty && !isThinking }

    /// True once at least one tile is on the board — the match is under way and
    /// its setup can no longer be changed (only left).
    var hasStarted: Bool { state.board.tileCount > 0 }

    func humanControls(_ color: PlayerColor) -> Bool {
        options.mode == .twoPlayer || color != options.aiColor
    }

    var statusText: String {
        switch state.result {
        case .win(let c): return "\(c == .white ? "White" : "Black") wins!"
        case .draw: return "Draw"
        case .ongoing:
            if isThinking { return "Computer is thinking…" }
            let who = current == .white ? "White" : "Black"
            if state.mustPlaceQueen { return "\(who): place your Queen" }
            return "\(who) to move"
        }
    }

    // MARK: New game / undo

    func newGame(options: GameOptions? = nil) {
        if let options { self.options = options }
        state = GameState(config: Self.config(for: self.options))
        history.removeAll()
        selection = .none
        targets = []
        isThinking = false
        pendingResume = nil
        GamePersistence.clear()
        scheduleAIIfNeeded()
    }

    func undo() {
        guard canUndo else { return }
        // Undo back to the last position the human was to act on (skip the AI ply).
        var restored = history.removeLast()
        if options.mode == .vsAI, restored.current == options.aiColor, let prev = history.popLast() {
            restored = prev
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            state = restored
        }
        selection = .none
        targets = []
        persist()
    }

    // MARK: Resume / leave

    /// Continue the interrupted match the player chose to keep.
    func resume() {
        guard let saved = pendingResume else { return }
        options = saved.options
        state = saved.state
        history = saved.history
        selection = .none
        targets = []
        isThinking = false
        pendingResume = nil
        scheduleAIIfNeeded()
        autoPassIfHumanStuck()
    }

    /// Discard the interrupted match and start fresh with its options.
    func discardResume() {
        let opts = pendingResume?.options ?? options
        pendingResume = nil
        newGame(options: opts)
    }

    /// Abandon the current match and return to a fresh, not-yet-started game with
    /// the same options (so the setup sheet becomes editable again).
    func leaveMatch() {
        newGame(options: options)
    }

    /// Apply settings to the not-yet-started game. Ignored once play has begun —
    /// there's no "Start" step; closing the setup sheet is what commits them.
    func applySetup(_ newOptions: GameOptions) {
        guard !hasStarted, newOptions != options else { return }
        newGame(options: newOptions)
    }

    // MARK: Selection & tapping

    /// Tap on a tile in the player's hand tray.
    func selectHand(_ bug: Bug, _ color: PlayerColor) {
        guard !isThinking, state.result == .ongoing,
              color == current, humanControls(color) else { return }

        if case let .hand(b, c) = selection, b == bug, c == color {
            clearSelection(); return
        }
        selection = .hand(bug, color)
        var cells = Set(MoveGenerator.placementCells(state))
        if state.mustPlaceQueen && bug != .queen { cells = [] }
        if options.tournamentOpening, state.currentTurnIndex == 1,
           !state.queenPlaced(color), bug == .queen { cells = [] }
        targets = cells
    }

    /// Tap on a cell of the board (occupied → maybe select/beetle-target;
    /// empty → maybe a move target).
    func tapHex(_ hex: Hex) {
        guard !isThinking, state.result == .ongoing else { return }

        if targets.contains(hex) {
            commitToTarget(hex)
            return
        }
        if let top = state.board.topPiece(hex), top.color == current, humanControls(top.color) {
            selectBoardPiece(id: top.id, at: hex)
            return
        }
        clearSelection()
    }

    func isSelected(pieceID: Int) -> Bool {
        if case let .board(id, _) = selection { return id == pieceID }
        return false
    }

    private func selectBoardPiece(id: Int, at hex: Hex) {
        if case let .board(sel, _) = selection, sel == id {
            clearSelection(); return
        }
        selection = .board(pieceID: id, hex: hex)
        targets = Set(MoveGenerator.destinations(for: id, in: state))
        if targets.isEmpty { impact(.rigid) }  // nothing to do, but show the pickup
    }

    private func clearSelection() {
        selection = .none
        targets = []
    }

    /// Tap on empty table space: drop whatever is picked up.
    func deselect() {
        guard !isThinking else { return }
        clearSelection()
    }

    private func commitToTarget(_ hex: Hex) {
        let move: Move
        switch selection {
        case let .hand(bug, _): move = .place(bug, at: hex)
        case let .board(id, from): move = .move(pieceID: id, from: from, to: hex)
        case .none: return
        }
        commit(move)
    }

    // MARK: Applying moves

    private func commit(_ move: Move) {
        history.append(state)
        clearSelection()
        impact(.light)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            state.apply(move)
        }
        if state.result != .ongoing { announceEnd() }
        persist()
        scheduleAIIfNeeded()
        autoPassIfHumanStuck()
    }

    // MARK: AI

    private func scheduleAIIfNeeded() {
        guard options.mode == .vsAI,
              state.result == .ongoing,
              current == options.aiColor,
              !isThinking else { return }

        isThinking = true
        let snapshot = state
        let difficulty = options.difficulty
        Task { [weak self] in
            let move = await Self.computeAIMove(for: snapshot, difficulty: difficulty)
            // A short beat so the "thinking" state is visible and moves feel deliberate.
            try? await Task.sleep(for: .milliseconds(350))
            guard let self else { return }
            self.isThinking = false
            guard self.state == snapshot else { return }  // state changed (e.g. new game)
            if let move {
                self.history.append(self.state)
                self.impact(.light)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    self.state.apply(move)
                }
                if self.state.result != .ongoing { self.announceEnd() }
                self.persist()
                self.scheduleAIIfNeeded()
                self.autoPassIfHumanStuck()
            }
        }
    }

    /// If it's a human's turn but they have no legal placement or move, pass for
    /// them automatically after a short beat. Prevents a "no moves" position from
    /// soft-locking the game and lets the opponent keep pressing for the win.
    private func autoPassIfHumanStuck() {
        guard state.result == .ongoing, !isThinking,
              humanControls(current), state.legalMoves() == [.pass] else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, self.state.result == .ongoing, !self.isThinking,
                  self.humanControls(self.current),
                  self.state.legalMoves() == [.pass] else { return }
            self.commit(.pass)
        }
    }

    // MARK: Persistence

    /// Cache the match after a move. Clears the cache once the game is over or
    /// hasn't really begun — there's nothing to resume in those cases.
    private func persist() {
        guard state.result == .ongoing, hasStarted else {
            GamePersistence.clear(); return
        }
        GamePersistence.save(SavedGame(options: options, state: state, history: history))
    }

    /// Save immediately — used when the app is about to be backgrounded/killed.
    func persistNow() {
        guard pendingResume == nil else { return }
        persist()
    }

    /// Every match includes the Mosquito **and** the Ladybug for both sides,
    /// alongside the base five bugs — not settings toggles, just part of the
    /// standard roster this app ships.
    private static func config(for options: GameOptions) -> GameConfig {
        GameConfig(tournamentOpening: options.tournamentOpening, expansions: [.mosquito, .ladybug])
    }

    /// Runs the search off the main actor.
    private static func computeAIMove(for state: GameState, difficulty: HiveAI.Difficulty) async -> Move? {
        await Task.detached(priority: .userInitiated) {
            var rng = SystemRandomNumberGenerator()
            return HiveAI.bestMove(for: state, difficulty: difficulty, timeLimit: 2.0, rng: &rng)
        }.value
    }

    // MARK: Feedback

    private func announceEnd() {
        clearSelection()
        switch state.result {
        case .win: notify(.success)
        case .draw: notify(.warning)
        case .ongoing: break
        }
    }

    private func impact(_ style: FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style.uiStyle)
        generator.impactOccurred()
        #endif
    }

    private func notify(_ type: FeedbackType) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(type.uiType)
        #endif
    }

    enum FeedbackStyle { case light, rigid
        #if canImport(UIKit)
        var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle { self == .light ? .light : .rigid }
        #endif
    }
    enum FeedbackType { case success, warning
        #if canImport(UIKit)
        var uiType: UINotificationFeedbackGenerator.FeedbackType { self == .success ? .success : .warning }
        #endif
    }
}

/// Tiny deterministic RNG for the demo seed (xorshift).
private struct DemoRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
