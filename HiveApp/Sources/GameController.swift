import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// Options chosen when starting a game.
struct GameOptions: Equatable {
    enum Mode: String, CaseIterable, Identifiable { case vsAI, twoPlayer
        var id: String { rawValue }
        var label: String { self == .vsAI ? "Vs. Computer" : "Two Players" }
    }
    var mode: Mode = .vsAI
    var humanColor: PlayerColor = .white          // in vs-AI, the side the human plays
    var difficulty: HiveAI.Difficulty = .medium
    var tournamentOpening: Bool = false

    var aiColor: PlayerColor { humanColor.opponent }
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

    /// What the player currently has "picked up".
    enum Selection: Equatable {
        case none
        case hand(Bug, PlayerColor)
        case board(pieceID: Int, hex: Hex)
    }
    private(set) var selection: Selection = .none

    init(options: GameOptions = GameOptions()) {
        self.options = options
        self.state = GameState(config: .init(tournamentOpening: options.tournamentOpening))
        if ProcessInfo.processInfo.environment["HIVE_DEMO"] == "1" {
            loadDemo()
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
        state = GameState(config: .init(tournamentOpening: self.options.tournamentOpening))
        history.removeAll()
        selection = .none
        targets = []
        isThinking = false
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
        scheduleAIIfNeeded()
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
                self.scheduleAIIfNeeded()
            }
        }
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
