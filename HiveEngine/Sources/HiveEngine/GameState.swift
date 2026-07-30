import Foundation

/// Optional rule toggles.
public struct GameConfig: Sendable, Equatable, Codable {
    /// Tournament opening: a player may not place their Queen as their first tile.
    public var tournamentOpening: Bool
    /// Expansion tiles to include (subset of `.mosquito`, `.ladybug`, `.pillbug`).
    /// The base game leaves this empty. `.mosquito` and `.ladybug` have full
    /// movement rules; `.pillbug` places but can't yet move.
    public var expansions: Set<Bug>

    public init(tournamentOpening: Bool = false, expansions: Set<Bug> = []) {
        self.tournamentOpening = tournamentOpening
        self.expansions = expansions
    }

    public static let base = GameConfig()
}

/// The complete, self-contained state of a game. A pure value type: copying it
/// is cheap and side-effect free, which the AI relies on for search and the app
/// relies on for undo (by keeping a stack of past states).
public struct GameState: Sendable, Equatable, Codable {
    public private(set) var board: Board
    public private(set) var current: PlayerColor
    /// Tiles not yet placed, for both colours.
    public private(set) var unplaced: [Piece]
    /// How many turns each colour has completed.
    public private(set) var movesMade: [PlayerColor: Int]
    public private(set) var result: GameResult
    public let config: GameConfig
    /// The move just played, for highlighting/animation.
    public private(set) var lastMove: Move?

    public init(config: GameConfig = .base) {
        self.board = Board()
        self.current = .white
        self.movesMade = [.white: 0, .black: 0]
        self.result = .ongoing
        self.config = config
        self.lastMove = nil

        // Deterministically build each player's hand with stable tile ids.
        var pieces: [Piece] = []
        var nextID = 0
        var roster = Bug.baseGame
        for exp in [Bug.mosquito, .ladybug, .pillbug] where config.expansions.contains(exp) {
            roster.append(exp)
        }
        for color in [PlayerColor.white, .black] {
            for bug in roster {
                for _ in 0..<bug.baseCount {
                    pieces.append(Piece(id: nextID, bug: bug, color: color))
                    nextID += 1
                }
            }
        }
        self.unplaced = pieces
    }

    // MARK: Derived state

    /// The turn number the current player is about to play (1-based).
    public var currentTurnIndex: Int { (movesMade[current] ?? 0) + 1 }

    public func queenPlaced(_ color: PlayerColor) -> Bool {
        !unplaced.contains { $0.color == color && $0.bug == .queen }
    }

    /// True when the current player is on their fourth turn and still owes a Queen.
    public var mustPlaceQueen: Bool {
        currentTurnIndex == 4 && !queenPlaced(current)
    }

    /// Unplaced tiles for a colour, grouped by bug in display order.
    public func hand(_ color: PlayerColor) -> [(bug: Bug, count: Int)] {
        var order = Bug.baseGame
        for exp in [Bug.mosquito, .ladybug, .pillbug] where config.expansions.contains(exp) {
            order.append(exp)
        }
        return order.compactMap { bug in
            let count = unplaced.filter { $0.color == color && $0.bug == bug }.count
            return count > 0 ? (bug, count) : nil
        }
    }

    func nextUnplaced(_ bug: Bug, _ color: PlayerColor) -> Piece? {
        unplaced.first { $0.bug == bug && $0.color == color }
    }

    // MARK: Move access

    public func legalMoves() -> [Move] { MoveGenerator.legalMoves(self) }

    public func isLegal(_ move: Move) -> Bool { legalMoves().contains(move) }

    // MARK: Mutation

    /// Apply a move. The caller is responsible for legality (the UI and AI only
    /// ever pass moves produced by the generator).
    public mutating func apply(_ move: Move) {
        switch move {
        case let .place(bug, hex):
            if let piece = nextUnplaced(bug, current) {
                board.push(piece, at: hex)
                unplaced.removeAll { $0.id == piece.id }
            }
        case let .move(pieceID, from, to):
            if let idx = board.stack(from).firstIndex(where: { $0.id == pieceID }),
               idx == board.height(from) - 1 {
                let piece = board.pop(at: from)!
                board.push(piece, at: to)
            }
        case .pass:
            break
        }

        movesMade[current, default: 0] += 1
        lastMove = move
        result = evaluateResult()
        if result == .ongoing {
            current = current.opponent
        }
    }

    /// A copy with `move` applied — convenient for search.
    public func applying(_ move: Move) -> GameState {
        var copy = self
        copy.apply(move)
        return copy
    }

    // MARK: Win detection

    /// The cell holding a colour's Queen (anywhere in the stack), if placed.
    public func queenHex(_ color: PlayerColor) -> Hex? {
        for (hex, stack) in board.stacks
        where stack.contains(where: { $0.bug == .queen && $0.color == color }) {
            return hex
        }
        return nil
    }

    /// How many of a Queen's six sides are occupied (0 if the Queen is unplaced).
    public func queenSurroundCount(_ color: PlayerColor) -> Int {
        guard let hex = queenHex(color) else { return 0 }
        return hex.neighbors.count { board.isOccupied($0) }
    }

    private func queenSurrounded(_ color: PlayerColor) -> Bool {
        queenHex(color).map { hex in hex.neighbors.allSatisfy { board.isOccupied($0) } } ?? false
    }

    private func evaluateResult() -> GameResult {
        let whiteLost = queenSurrounded(.white)
        let blackLost = queenSurrounded(.black)
        switch (whiteLost, blackLost) {
        case (true, true): return .draw
        case (true, false): return .win(.black)
        case (false, true): return .win(.white)
        case (false, false): return .ongoing
        }
    }
}

extension GameState {
    /// Construct an arbitrary position directly. Intended for tests, puzzle
    /// setups, and the app's guided tutorial drills; normal play should go
    /// through `apply(_:)`.
    public init(board: Board,
                current: PlayerColor,
                unplaced: [Piece],
                movesMade: [PlayerColor: Int],
                config: GameConfig = .base) {
        self.board = board
        self.current = current
        self.unplaced = unplaced
        self.movesMade = movesMade
        self.result = .ongoing
        self.config = config
        self.lastMove = nil
        self.result = evaluateResult()
    }
}
