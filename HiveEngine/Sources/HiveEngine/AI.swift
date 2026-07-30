import Foundation

/// A negamax + alpha-beta opponent with a queen-surrounding heuristic.
///
/// The evaluation is strictly zero-sum (symmetric between the two colours), as
/// negamax requires: any advantage for one side is an equal disadvantage for the
/// other.
///
/// Design goals (see CLAUDE.md → "The AI"): the computer should actually try to
/// *win*, not merely hinder. Three things enforce that:
///   1. An immediate winning move is always taken, before any random blunder.
///   2. Terminal scores decay with distance, so it heads straight for the fastest
///      kill instead of shuffling among equal-value winning lines.
///   3. Blunders are disabled in "critical" positions (either queen nearly
///      surrounded), so lower difficulties still finish — and defend — when it
///      matters, while staying beatable in the quiet midgame.
public enum HiveAI {

    public enum Difficulty: String, CaseIterable, Sendable, Codable {
        /// A deliberately very weak, very forgiving tier for the in-app tutorial
        /// bot — not offered in the normal difficulty picker (see
        /// `GameMenuSheet`). Still takes an immediate win and still defends a
        /// queen in real danger (that safety net in `bestMove` applies to every
        /// tier), so a match still resolves properly; it just blunders often
        /// enough in the quiet midgame that a total beginner can win.
        case megaEasy
        case easy, medium, hard

        var searchDepth: Int {
            switch self {
            case .megaEasy: return 1
            case .easy: return 1
            case .medium: return 2
            case .hard: return 4
            }
        }

        /// Chance of playing a non-optimal move in a *non-critical* position, to
        /// stay beatable. Never applied when a queen is under threat.
        var blunderChance: Double {
            switch self {
            case .megaEasy: return 0.6
            case .easy: return 0.25
            case .medium: return 0.0
            case .hard: return 0.0
            }
        }
    }

    static let winScore = 1_000_000

    /// Choose a move for the side to play. `timeLimit` caps the search wall-clock
    /// for iterative deepening; pass a generous value for deterministic depth.
    public static func bestMove(
        for state: GameState,
        difficulty: Difficulty = .medium,
        timeLimit: TimeInterval = 2.0,
        rng: inout some RandomNumberGenerator
    ) -> Move? {
        guard state.result == .ongoing else { return nil }
        let moves = state.legalMoves()
        guard moves.count > 1 else { return moves.first }

        let me = state.current

        // 1) Never stall on a kill: if any move ends the game in our favour, play
        //    it immediately (this also short-circuits the blunder roll below).
        for move in moves where state.applying(move).result == .win(me) {
            return move
        }

        // 2) Occasional deliberate blunder on lower difficulties — but only when
        //    neither queen is in danger, so the AI still fights to win/defend at
        //    the moments that decide the game.
        let critical = state.queenSurroundCount(me.opponent) >= 4
                    || state.queenSurroundCount(me) >= 4
        if difficulty.blunderChance > 0, !critical,
           Double.random(in: 0..<1, using: &rng) < difficulty.blunderChance {
            return moves.randomElement(using: &rng)
        }

        let ordered = orderMoves(moves, state: state)
        let deadline = Date().addingTimeInterval(timeLimit)

        var best = ordered[0]
        var bestScore = -winScore - 1

        // Iterative deepening: each pass reuses the previous best as a first guess.
        for depth in 1...difficulty.searchDepth {
            var alpha = -winScore - 1
            let beta = winScore + 1
            var localBest = best
            var localBestScore = -winScore - 1
            var timedOut = false

            for move in orderMoves(ordered, state: state, preferred: best) {
                if depth > 1 && Date() > deadline { timedOut = true; break }
                let child = state.applying(move)
                let score = -negamax(child, depth: depth - 1,
                                     alpha: -beta, beta: -alpha,
                                     toMove: me.opponent, ply: 1, deadline: deadline)
                if score > localBestScore {
                    localBestScore = score
                    localBest = move
                }
                alpha = max(alpha, score)
            }

            if !timedOut {
                best = localBest
                bestScore = localBestScore
            }
            if bestScore >= winScore || timedOut { break }
        }
        return best
    }

    // MARK: Search

    private static func negamax(
        _ state: GameState,
        depth: Int,
        alpha: Int,
        beta: Int,
        toMove: PlayerColor,
        ply: Int,
        deadline: Date
    ) -> Int {
        // Mate-distance aware terminal scoring: a win reached sooner is worth
        // more, so the AI drives to the quickest kill rather than dithering.
        switch state.result {
        case .win(let winner):
            let magnitude = winScore - ply
            return winner == toMove ? magnitude : -magnitude
        case .draw:
            return 0
        case .ongoing:
            if depth == 0 { return evaluate(state, for: toMove) }
        }

        var alpha = alpha
        var best = -winScore - 1
        let moves = orderMoves(state.legalMoves(), state: state)

        for move in moves {
            let child = state.applying(move)
            let score = -negamax(child, depth: depth - 1,
                                 alpha: -beta, beta: -alpha,
                                 toMove: toMove.opponent, ply: ply + 1, deadline: deadline)
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }              // pruned
            if depth > 2 && Date() > deadline { break }
        }
        return best
    }

    // MARK: Evaluation (zero-sum)

    /// Board score from `me`'s point of view. Positive is good for `me`.
    public static func evaluate(_ state: GameState, for me: PlayerColor) -> Int {
        switch state.result {
        case .win(let winner): return winner == me ? winScore : -winScore
        case .draw: return 0
        case .ongoing: break
        }

        let opp = me.opponent
        let enemySurround = state.queenSurroundCount(opp)   // filling this wins for me
        let mySurround = state.queenSurroundCount(me)       // filling this loses for me

        var score = 0
        // Surrounding the enemy queen (and not being surrounded) dominates. The
        // quadratic term makes the last couple of sides far more urgent, so the
        // AI presses the attack instead of merely obstructing.
        score += 40 * (enemySurround * enemySurround - mySurround * mySurround)
        score += 10 * (enemySurround - mySurround)

        // Mobility proxy: how many of each side's tiles are free to move.
        score += 2 * (mobility(state, me) - mobility(state, opp))

        // A queen still boxed in by enemy tiles that themselves can't leave is
        // extra dangerous; approximate with "enemy tiles adjacent to my queen".
        score -= 3 * enemyTilesAround(state, queenOf: me)
        score += 3 * enemyTilesAround(state, queenOf: opp)

        return score
    }

    /// Count of a colour's top tiles that are structurally free to move.
    private static func mobility(_ state: GameState, _ color: PlayerColor) -> Int {
        let board = state.board
        guard state.queenPlaced(color) else { return 0 }
        var count = 0
        for hex in board.occupiedCells where board.topPiece(hex)?.color == color {
            if board.height(hex) > 1 || !board.isCutVertex(hex) { count += 1 }
        }
        return count
    }

    /// Tiles of the OTHER colour sitting next to `color`'s queen.
    private static func enemyTilesAround(_ state: GameState, queenOf color: PlayerColor) -> Int {
        guard let hex = state.queenHex(color) else { return 0 }
        return hex.neighbors.count { state.board.topPiece($0)?.color == color.opponent }
    }

    // MARK: Move ordering

    /// Order moves to attack: land next to the enemy queen first, then develop.
    /// `preferred` (if any) is floated to the very front for iterative deepening.
    private static func orderMoves(_ moves: [Move], state: GameState, preferred: Move? = nil) -> [Move] {
        let enemyQueen = state.queenHex(state.current.opponent)
        func key(_ move: Move) -> Int {
            if let preferred, move == preferred { return 10_000 }
            let target: Hex
            switch move {
            case let .place(_, hex): target = hex
            case let .move(_, _, to): target = to
            case .pass: return -1
            }
            guard let q = enemyQueen else { return 0 }
            if target.isAdjacent(to: q) { return 100 }
            return -target.distance(to: q)
        }
        return moves.sorted { key($0) > key($1) }
    }
}
