import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Animation System

enum AnimationPhase: Equatable {
    case none
    case drop(piece: Piece, at: Hex)
    /// A piece travelling along its reconstructed route (`MoveGenerator.path`).
    /// The path carries the bug's real movement: step-by-step slides, the
    /// grasshopper's overflown line, beetle stack levels, the ladybug's
    /// up-over-down — so watching a move teaches how the bug moves.
    case travel(piece: Piece, path: MovePath)

    /// True while a staged piece animation is in flight (input is locked out).
    var isAnimating: Bool { self != .none }
}

/// Options chosen when starting a game. `Codable` so a match can be cached.
struct GameOptions: Equatable, Codable {
    enum Mode: String, CaseIterable, Identifiable, Codable { case vsAI, twoPlayer
        var id: String { rawValue }
        var label: String { self == .vsAI ? "Vs. Computador" : "Dois Jogadores" }
    }
    enum ColorChoice: String, CaseIterable, Identifiable, Codable {
        case random = "random"
        case white = "white"
        case black = "black"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .random: return "Sorteio 🎲"
            case .white: return "Brancas (primeiro)"
            case .black: return "Pretas"
            }
        }
    }
    var mode: Mode = .vsAI
    var colorChoice: ColorChoice = .random
    var humanColor: PlayerColor = .white          // in vs-AI, the side the human plays
    var difficulty: HiveAI.Difficulty = .medium
    var tournamentOpening: Bool = false

    var aiColor: PlayerColor { humanColor.opponent }

    /// Preset for the "Play Tutorial" action: vs. a deliberately very weak,
    /// forgiving bot, human plays White, no tournament restriction.
    static var tutorial: GameOptions {
        var options = GameOptions()
        options.mode = .vsAI
        options.colorChoice = .white
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

    /// When non-nil, shows the ColorDrawOverlay animation revealing which side
    /// the human was assigned for this match.
    private(set) var pendingColorDraw: PlayerColor? = nil

    /// What the player currently has "picked up".
    enum Selection: Equatable {
        case none
        case hand(Bug, PlayerColor)
        case board(pieceID: Int, hex: Hex)
    }
    private(set) var selection: Selection = .none

    // MARK: - Drag State
    /// Tracks an in-flight drag (from hand or board). Separate from `selection`
    /// so the two input modes coexist: starting a drag clears the tap selection
    /// and vice versa.
    let dragState = DragState()
    var recenterTrigger: Int = 0

    func recenterBoard() {
        recenterTrigger += 1
    }

    // MARK: - Animation State
    var animationPhase: AnimationPhase = .none
    var animationProgress: CGFloat = 0
    private var animationTask: Task<Void, Never>?
    private var pendingMove: (move: Move, board: Board)?

    // MARK: - Player Feedback

    /// A short-lived coaching or error message shown above the hand trays —
    /// the app's way of *answering* taps that don't do what the player
    /// expected, instead of ignoring them in silence.
    struct Toast: Equatable {
        let id: Int
        let text: String
        let icon: String?
    }
    private(set) var toast: Toast?

    /// The board tile a rejected tap landed on; `seq` increments on every
    /// rejection so tapping the same tile twice shakes it twice.
    struct Rejection: Equatable {
        let hex: Hex
        let seq: Int
    }
    private(set) var rejection: Rejection?

    private var toastSeq = 0
    private var rejectionSeq = 0
    private var toastTask: Task<Void, Never>?
    private var lastToastText: String?
    private var lastToastAt = Date.distantPast
    /// One-time coaching: the first time a piece is picked up, teach the
    /// select-then-tap-a-highlighted-cell flow.
    private var didCoachTargetTap = false

    /// Show a toast, auto-dismissed after a few seconds. Identical messages
    /// within ~2 s are dropped so hammering the same invalid tap doesn't
    /// flicker the pill — but the error haptic still fires every time.
    func showToast(_ text: String, icon: String? = nil) {
        let now = Date()
        if text == lastToastText, now.timeIntervalSince(lastToastAt) < 2.0 { return }
        lastToastText = text
        lastToastAt = now
        toastSeq += 1
        toast = Toast(id: toastSeq, text: text, icon: icon)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard let self, !Task.isCancelled else { return }
            self.toast = nil
        }
    }

    /// Shake the tapped tile, buzz an error, and explain why the tap did
    /// nothing — the trio that turns a "dead" interaction into feedback.
    private func rejectTap(at hex: Hex, message: String) {
        rejectionSeq += 1
        rejection = Rejection(hex: hex, seq: rejectionSeq)
        Haptics.error()
        showToast(message, icon: "hand.raised.fill")
    }

    /// One-time nudge teaching the core interaction: pick up, then tap a
    /// highlighted cell.
    private func coachTargetTap() {
        guard !didCoachTargetTap else { return }
        didCoachTargetTap = true
        showToast("Agora toque em uma casa destacada", icon: "hand.tap.fill")
    }

    /// The system "Reduce Motion" accessibility setting. When on, the staged
    /// piece animations (drop, slide, jump, climb) and any springy scaling are
    /// replaced by a calm crossfade so motion-sensitive players still get clear,
    /// readable feedback without movement.
    var reduceMotion: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }

    init(options: GameOptions = GameOptions()) {
        var opts = options
        if opts.mode == .vsAI && opts.colorChoice == .random {
            opts.humanColor = Bool.random() ? .white : .black
        }
        self.options = opts
        self.state = GameState(config: Self.config(for: opts))

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
        case .win(let c):
            if options.mode == .vsAI {
                return c == options.humanColor ? "Você venceu! 🎉" : "Oponente venceu!"
            }
            return "\(c == .white ? "Brancas" : "Pretas") vencem!"
        case .draw: return "Empate"
        case .ongoing:
            if isThinking { return "Computador pensando…" }
            if options.mode == .vsAI {
                if current == options.humanColor {
                    if state.mustPlaceQueen { return "Sua vez: posicione sua Rainha" }
                    return "Sua vez"
                } else {
                    return "Vez do oponente"
                }
            } else {
                let who = current == .white ? "Brancas" : "Pretas"
                if state.mustPlaceQueen { return "\(who): posicione sua Rainha" }
                return "Vez das \(who)"
            }
        }
    }

    // MARK: New game / undo

    func newGame(options: GameOptions? = nil, showDrawAnimation: Bool = true) {
        if let options { self.options = options }

        if self.options.mode == .vsAI {
            switch self.options.colorChoice {
            case .random:
                self.options.humanColor = Bool.random() ? .white : .black
            case .white:
                self.options.humanColor = .white
            case .black:
                self.options.humanColor = .black
            }
        }

        state = GameState(config: Self.config(for: self.options))
        history.removeAll()
        selection = .none
        targets = []
        hint = nil
        isThinking = false
        pendingResume = nil
        toast = nil
        toastTask?.cancel()
        lastToastText = nil
        rejection = nil
        didCoachTargetTap = false
        GamePersistence.clear()

        if showDrawAnimation && self.options.mode == .vsAI {
            pendingColorDraw = self.options.humanColor
        } else {
            pendingColorDraw = nil
            scheduleAIIfNeeded()
        }
    }

    /// Called when the ColorDrawOverlay finishes or is dismissed by the player.
    func completeColorDraw() {
        pendingColorDraw = nil
        scheduleAIIfNeeded()
    }

    func undo() {
        guard canUndo else { return }
        Haptics.light()
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
        hint = nil
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

    /// Discard the interrupted match and return cleanly to home without coin toss.
    func discardResume() {
        let opts = pendingResume?.options ?? options
        pendingResume = nil
        GamePersistence.clear()
        newGame(options: opts, showDrawAnimation: false)
    }

    /// Abandon the current match and return cleanly without coin toss.
    func leaveMatch() {
        GamePersistence.clear()
        newGame(options: options, showDrawAnimation: false)
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
        guard state.result == .ongoing else { return }
        guard color == current, humanControls(color), !isThinking else {
            // Tapped a tray that can't act right now — say why instead of
            // doing nothing (a silent no-op reads as a broken app).
            let message: String
            if options.mode == .vsAI && color == options.aiColor {
                message = "Essas peças são do computador"
            } else if isThinking {
                message = "Aguarde: o computador está jogando"
            } else if options.mode == .vsAI {
                message = current == options.humanColor ? "Agora é a sua vez" : "Aguarde a vez do oponente"
            } else {
                message = "Agora é a vez das \(current == .white ? "Brancas" : "Pretas")"
            }
            Haptics.error()
            showToast(message, icon: "hourglass")
            return
        }

        if case let .hand(b, c) = selection, b == bug, c == color {
            clearSelection(); return
        }
        selection = .hand(bug, color)
        hint = nil                     // the player is acting on their own now
        Haptics.selection()
        var cells = Set(MoveGenerator.placementCells(state))
        if state.mustPlaceQueen && bug != .queen { cells = [] }
        if options.tournamentOpening, state.currentTurnIndex == 1,
           !state.queenPlaced(color), bug == .queen { cells = [] }
        targets = cells
        if targets.isEmpty {
            if state.mustPlaceQueen && bug != .queen {
                Haptics.error()
                showToast("Você precisa posicionar sua Rainha primeiro", icon: "crown.fill")
            }
        } else {
            coachTargetTap()
        }
    }

    /// Tap on a cell of the board (occupied → maybe select/beetle-target;
    /// empty → maybe a move target).
    func tapHex(_ hex: Hex) {
        guard !isThinking, state.result == .ongoing else { return }

        if targets.contains(hex) {
            commitToTarget(hex)
            return
        }
        if let top = state.board.topPiece(hex) {
            if top.color == current, humanControls(top.color) {
                selectBoardPiece(id: top.id, at: hex)
            } else {
                // An opponent tile: the single most common "why isn't this
                // working?" tap. Shake it, buzz, and explain.
                rejectTap(at: hex, message: "Essa peça é do oponente")
            }
            return
        }
        // Empty, non-target cell: put the picked-up piece back down.
        clearSelection()
    }

    func isSelected(pieceID: Int) -> Bool {
        if case let .board(id, _) = selection { return id == pieceID }
        return false
    }

    /// True when the player has any piece picked up — a tile already on the
    /// board *or* a tile in the hand tray. Drives the subtle "hold to see piece
    /// movement" hint; both kinds of selection can be press-and-held to read the
    /// bug's movement rules.
    var isPieceSelected: Bool {
        switch selection {
        case .board, .hand: return true
        case .none: return false
        }
    }

    private func selectBoardPiece(id: Int, at hex: Hex) {
        if case let .board(sel, _) = selection, sel == id {
            clearSelection(); return
        }
        selection = .board(pieceID: id, hex: hex)
        hint = nil                     // the player is acting on their own now
        Haptics.selection()
        targets = Set(MoveGenerator.destinations(for: id, in: state))
        if targets.isEmpty {
            // Pinned or blocked: say so, otherwise the pickup looks broken.
            impact(.rigid)
            showToast("Esta peça não pode se mover agora", icon: "lock.fill")
        } else {
            coachTargetTap()
        }
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

    // MARK: - Drag & Drop

    /// Start dragging a piece from the hand or the board. Computes the legal
    /// targets (just like tap-select) and fills `dragState`.
    func beginDrag(_ source: DragState.Source) {
        guard state.result == .ongoing, !isThinking, animationPhase == .none else { return }

        let piece: Piece?
        var dragTargets: Set<Hex>

        switch source {
        case let .hand(bug, color):
            guard color == current, humanControls(color) else { return }
            piece = Piece(id: -1, bug: bug, color: color)
            var cells = Set(MoveGenerator.placementCells(state))
            if state.mustPlaceQueen && bug != .queen { cells = [] }
            if options.tournamentOpening, state.currentTurnIndex == 1,
               !state.queenPlaced(color), bug == .queen { cells = [] }
            dragTargets = cells

        case let .board(pieceID, from):
            guard let top = state.board.topPiece(from),
                  top.id == pieceID, top.color == current,
                  humanControls(top.color) else { return }
            piece = top
            dragTargets = Set(MoveGenerator.destinations(for: pieceID, in: state))
        }

        guard let piece, !dragTargets.isEmpty else {
            Haptics.error()
            return
        }

        // A drag supersedes any existing tap selection or hint.
        clearSelection()
        hint = nil
        Haptics.selection()
        dragState.begin(source: source, piece: piece, targets: dragTargets)
    }

    /// Drop the dragged piece onto `hex`. If it is a valid target the move is
    /// committed through the normal animation pipeline; otherwise the drag is
    /// cancelled.
    func commitDrag(to hex: Hex) {
        guard dragState.isDragging, dragState.validTargets.contains(hex) else {
            cancelDrag()
            return
        }
        let move: Move
        switch dragState.source {
        case let .hand(bug, _):
            move = .place(bug, at: hex)
        case let .board(pieceID, from):
            move = .move(pieceID: pieceID, from: from, to: hex)
        case .none:
            cancelDrag()
            return
        }
        dragState.reset()
        commit(move)
    }

    /// Cancel the current drag — the piece returns to where it was.
    func cancelDrag() {
        guard dragState.isDragging else { return }
        dragState.reset()
    }

    // MARK: - Hints

    /// The move the app is currently suggesting to the player, or `nil` when no
    /// hint is showing. Rendered as a glowing marker on the destination cell (and
    /// a ring on the source piece / hand chip) so a beginner can see *what* a good
    /// play looks like, not just be told one exists.
    private(set) var hint: Move?
    /// True while a hint is being computed off the main actor.
    private(set) var isComputingHint = false

    /// Ask the engine for a strong move for the side the player controls and
    /// highlight it on the board. Runs the search off the main actor so the UI
    /// never stalls; the result is dropped if the position changed meanwhile.
    func requestHint() {
        guard !isThinking, !isComputingHint, hint == nil,
              state.result == .ongoing, humanControls(current) else { return }

        isComputingHint = true
        let snapshot = state
        Task { [weak self] in
            let move = await Self.computeAIMove(for: snapshot, difficulty: .hard, timeLimit: 1.5)
            guard let self else { return }
            self.isComputingHint = false
            // Position moved on (or a hint already shows) — discard the stale result.
            guard self.state == snapshot, self.hint == nil else { return }
            guard let move, move != .pass else { return }
            self.clearSelection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.hint = move
            }
            Haptics.light()
        }
    }

    func dismissHint() {
        guard hint != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) { hint = nil }
    }

    /// Commit the currently-shown suggestion — lets a beginner accept a hint by
    /// tapping its glowing destination marker instead of replaying it by hand.
    func playHint() {
        guard let move = hint, !isThinking, state.result == .ongoing else { return }
        commit(move)
    }

    /// The cell a hint places or moves a piece *onto* — where the glowing marker goes.
    var hintToHex: Hex? {
        switch hint {
        case let .place(_, hex): return hex
        case let .move(_, _, to): return to
        case .pass, nil: return nil
        }
    }

    /// The cell a hint lifts a piece *from* (board moves only) — gets a source ring.
    var hintFromHex: Hex? {
        if case let .move(_, from, _) = hint { return from }
        return nil
    }

    /// The bug a hint wants placed from the hand (placements only) — its chip glows.
    var hintHandBug: Bug? {
        if case let .place(bug, _) = hint { return bug }
        return nil
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

    private func commit(_ move: Move, animated: Bool = true) {
        // Guard against input during animation
        guard animationPhase == .none else { return }

        history.append(state)
        clearSelection()
        hint = nil                     // a move was made — the suggestion is spent
        toastTask?.cancel()
        toast = nil                    // the player acted — any coaching is spent

        if animated && !reduceMotion {
            startAnimation(for: move, in: state) { [weak self] in
                guard let self else { return }
                self.state.apply(move)
                self.animationPhase = .none
                self.animationProgress = 0
                if self.state.result != .ongoing { self.announceEnd() }
                self.persist()
                self.scheduleAIIfNeeded()
                self.autoPassIfHumanStuck()
            }
        } else {
            applyPlain(move)
        }
    }

    /// Applies a move without the staged piece animation — used for `.pass`, as
    /// a fallback when a piece can't be found, and whenever Reduce Motion is on.
    /// With Reduce Motion it crossfades instead of springing, so motion-sensitive
    /// players get a calm, readable update rather than movement.
    private func applyPlain(_ move: Move) {
        impact(.light)
        let animation: Animation? = reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.42, dampingFraction: 0.78)
        withAnimation(animation) {
            state.apply(move)
        }
        if state.result != .ongoing { announceEnd() }
        persist()
        scheduleAIIfNeeded()
        autoPassIfHumanStuck()
    }

    // MARK: - Animation Helpers

    /// Reconstructs the move's route and animates the tile along it — the ant
    /// visibly slides hex by hex, the spider walks its three steps, the
    /// grasshopper arcs over the line it jumps, the beetle changes level, the
    /// ladybug climbs two tiles and drops. Watching a move teaches the rule.
    private func startAnimation(for move: Move, in stateBefore: GameState, completion: @escaping () -> Void) {
        switch move {
        case .place(let bug, at: let hex):
            let piece = Piece(id: -1, bug: bug, color: current)
            animationPhase = .drop(piece: piece, at: hex)
            Haptics.light()
            runAnimation(duration: 0.45) {
                completion()
                Haptics.medium()
            }

        case .move:
            guard let path = MoveGenerator.path(of: move, in: stateBefore),
                  let piece = stateBefore.board.topPiece(path.from) else {
                applyPlain(move)   // fallback: no route found, skip animation
                return
            }
            animationPhase = .travel(piece: piece, path: path)
            Haptics.light()
            runAnimation(duration: travelDuration(for: path), ticks: travelTicks(for: path)) {
                completion()
                Haptics.medium()
            }

        case .pass:
            applyPlain(move)   // no animation for pass — apply immediately
        }
    }

    /// Longer routes take longer to travel, but each extra step costs less than
    /// the last so a cross-board ant march doesn't outstay its welcome.
    private func travelDuration(for path: MovePath) -> TimeInterval {
        switch path.kind {
        case .slide:
            let segments = max(1, path.steps.count - 1)
            return min(0.95, 0.24 + 0.13 * TimeInterval(segments))
        case .jump:
            return 0.55
        case .climb:
            return 0.45
        case .overTheTop:
            return 0.85
        }
    }

    /// Tactile ticks fired as the tile lands on each intermediate step, so the
    /// step-by-step route is felt as well as seen. Jumps stay a single whoosh.
    private func travelTicks(for path: MovePath) -> Int {
        switch path.kind {
        case .slide, .overTheTop: return max(0, path.steps.count - 1)
        case .jump, .climb: return 0
        }
    }

    /// Drives `animationProgress` from 0 to 1 over `duration`. When `ticks` is
    /// set, fires a light tactile tick each time the tile crosses into the next
    /// segment of its route (the final landing tick is the completion haptic).
    private func runAnimation(duration: TimeInterval, ticks: Int = 0, completion: @escaping () -> Void) {
        animationTask?.cancel()
        let startTime = Date()
        animationTask = Task { @MainActor in
            var lastTick = 0
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(1.0, elapsed / duration)
                self.animationProgress = CGFloat(progress)
                if ticks > 0 {
                    let tick = Int(progress * Double(ticks))
                    if tick > lastTick && tick < ticks {
                        lastTick = tick
                        Haptics.selection()
                    }
                }
                if progress >= 1.0 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            if !Task.isCancelled {
                completion()
            }
        }
    }

    /// Hex position in pixels for animation rendering
    func pixelPosition(for hex: Hex, hexSize: CGFloat) -> CGPoint {
        let x = hexSize * (sqrt(3) * Double(hex.q) + sqrt(3)/2 * Double(hex.r))
        let y = hexSize * (3.0/2 * Double(hex.r))
        return CGPoint(x: x, y: y)
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
                self.commit(move, animated: true)
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
            self.showToast("Sem jogadas disponíveis — passando a vez", icon: "arrow.right.circle.fill")
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
    private static func computeAIMove(
        for state: GameState,
        difficulty: HiveAI.Difficulty,
        timeLimit: TimeInterval = 2.0
    ) async -> Move? {
        await Task.detached(priority: .userInitiated) {
            var rng = SystemRandomNumberGenerator()
            return HiveAI.bestMove(for: state, difficulty: difficulty, timeLimit: timeLimit, rng: &rng)
        }.value
    }

    // MARK: Feedback

    private func announceEnd() {
        clearSelection()
        switch state.result {
        case .win:
            notify(.success)
            Haptics.victory()
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
