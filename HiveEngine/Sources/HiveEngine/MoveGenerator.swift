import Foundation

/// Generates the legal moves for a game state.
public enum MoveGenerator {

    /// Every legal move for the player to act. Returns `[.pass]` only when the
    /// player genuinely has no placement and no piece move.
    public static func legalMoves(_ state: GameState) -> [Move] {
        guard state.result == .ongoing else { return [] }
        var moves = legalPlacements(state)
        moves += legalPieceMoves(state)
        return moves.isEmpty ? [.pass] : moves
    }

    // MARK: Placements

    /// The set of cells the current player may drop a new tile on (independent
    /// of which bug), following the "touch a friendly tile, touch no enemy tile"
    /// rule with the standard first-tile exceptions.
    public static func placementCells(_ state: GameState) -> [Hex] {
        let color = state.current
        let board = state.board

        if board.isEmpty { return [.origin] }

        let friendlyCells = board.occupiedCells.filter { board.topPiece($0)?.color == color }

        // A player's very first tile: no friendly tile exists yet. Placement is
        // allowed anywhere adjacent to the hive (the only time enemy-adjacency is
        // ignored), which in practice is beside the opponent's opening tile.
        if friendlyCells.isEmpty {
            var cells = Set<Hex>()
            for cell in board.occupiedCells {
                for n in board.emptyNeighbors(cell) { cells.insert(n) }
            }
            return Array(cells)
        }

        var candidates = Set<Hex>()
        for cell in friendlyCells {
            for empty in board.emptyNeighbors(cell) { candidates.insert(empty) }
        }
        // Reject any cell touching an enemy-topped tile.
        return candidates.filter { cell in
            !cell.neighbors.contains { board.topPiece($0)?.color == color.opponent }
        }
    }

    public static func legalPlacements(_ state: GameState) -> [Move] {
        let color = state.current
        let cells = placementCells(state)
        guard !cells.isEmpty else { return [] }

        // Which bugs may be placed this turn.
        var bugs = state.hand(color).map(\.bug)
        if state.mustPlaceQueen {
            bugs = bugs.contains(.queen) ? [.queen] : []
        } else if state.config.tournamentOpening
                    && state.currentTurnIndex == 1
                    && !state.queenPlaced(color) {
            bugs.removeAll { $0 == .queen }   // no Queen on the opening tile
        }

        var moves: [Move] = []
        for bug in bugs {
            for cell in cells {
                moves.append(.place(bug, at: cell))
            }
        }
        return moves
    }

    // MARK: Piece movement

    public static func legalPieceMoves(_ state: GameState) -> [Move] {
        let color = state.current
        // No tile may move until this player's Queen is on the board.
        guard state.queenPlaced(color) else { return [] }
        let board = state.board

        var moves: [Move] = []
        for hex in board.occupiedCells {
            guard let piece = board.topPiece(hex), piece.color == color else { continue }
            for dest in destinations(forTopOf: hex, piece: piece, board: board) {
                moves.append(.move(pieceID: piece.id, from: hex, to: dest))
            }
        }
        return moves
    }

    // MARK: - Immobility Diagnosis

    /// The precise reason why a piece on the board cannot be moved.
    public enum ImmobilityReason: Equatable, Sendable {
        case queenNotPlaced
        case oneHiveCutVertex
        case coveredByPiece
        case freedomToMoveBlocked
        case spiderNoExactPath
        case noValidMoves
    }

    /// Determines the exact didactic reason why a piece cannot move in the current state.
    public static func immobilityReason(for pieceID: Int, in state: GameState) -> ImmobilityReason {
        guard let hex = state.board.location(of: pieceID) else {
            return .noValidMoves
        }

        // Check if piece is covered beneath another piece in the stack
        guard let top = state.board.topPiece(hex), top.id == pieceID else {
            return .coveredByPiece
        }

        // Must place Queen before moving any piece
        if !state.queenPlaced(top.color) {
            return .queenNotPlaced
        }

        // One-Hive Rule: a ground tile that bridges/sustains the hive cannot move
        if state.board.height(hex) == 1 && state.board.isCutVertex(hex) {
            return .oneHiveCutVertex
        }

        // Lift piece to check physical sliding and reachability constraints
        var lifted = state.board
        lifted.pop(at: hex)

        switch top.bug {
        case .spider:
            let steps = Rules.groundSlideSteps(on: lifted, from: hex)
            if steps.isEmpty {
                return .freedomToMoveBlocked
            }
            let exact = Rules.exactSlideDestinations(on: lifted, from: hex, steps: 3)
            if exact.isEmpty {
                return .spiderNoExactPath
            }
        case .queen, .ant:
            let steps = Rules.groundSlideSteps(on: lifted, from: hex)
            if steps.isEmpty {
                return .freedomToMoveBlocked
            }
        case .beetle:
            if lifted.height(hex) == 0 {
                let steps = Rules.beetleDestinations(on: lifted, from: hex)
                if steps.isEmpty {
                    return .freedomToMoveBlocked
                }
            }
        default:
            break
        }

        return .noValidMoves
    }

    /// Legal destinations for the tile currently on top of `hex`. Public so the
    /// UI can highlight moves for a tapped tile.
    public static func destinations(for pieceID: Int, in state: GameState) -> [Hex] {
        guard state.result == .ongoing,
              let hex = state.board.location(of: pieceID),
              let piece = state.board.topPiece(hex),
              piece.id == pieceID,
              piece.color == state.current,
              state.queenPlaced(state.current)
        else { return [] }
        return destinations(forTopOf: hex, piece: piece, board: state.board)
    }

    private static func destinations(forTopOf hex: Hex, piece: Piece, board: Board) -> [Hex] {
        // One-Hive: a ground tile that bridges the hive cannot be lifted at all.
        if board.height(hex) == 1 && board.isCutVertex(hex) { return [] }

        // Lift the tile; the rest of the hive is what it slides against.
        var lifted = board
        lifted.pop(at: hex)
        if lifted.isEmpty { return [] } // nothing to move relative to

        switch piece.bug {
        case .queen:
            return Rules.groundSlideSteps(on: lifted, from: hex)
        case .ant:
            return Array(Rules.antReachable(on: lifted, from: hex))
        case .spider:
            return Array(Rules.exactSlideDestinations(on: lifted, from: hex, steps: 3))
        case .grasshopper:
            return Rules.grasshopperDestinations(on: lifted, from: hex)
        case .beetle:
            return Rules.beetleDestinations(on: lifted, from: hex)
        case .mosquito:
            // Having climbed atop the hive (only possible by copying a Beetle),
            // a mosquito is stuck copying the Beetle from then on — the tiles it
            // now touches up there are irrelevant to what got it up there. A
            // non-zero height *after* lifting means there was a tile beneath it.
            if lifted.height(hex) > 0 {
                return Rules.beetleDestinations(on: lifted, from: hex)
            }
            return Array(Rules.mosquitoGroundDestinations(on: lifted, from: hex))
        case .ladybug:
            return Array(Rules.ladybugDestinations(on: lifted, from: hex))
        case .pillbug:
            return [] // pillbug movement not yet implemented
        }
    }

    // MARK: Path reconstruction (for move animation)

    /// Reconstructs the route a legal move takes, so the app can animate the
    /// tile the way its bug actually travels. Returns `nil` for placements,
    /// passes, or if the move does not match the position (stale input).
    ///
    /// The reconstruction mirrors `destinations(forTopOf:)` bug by bug, using
    /// the same `Rules` primitives against the same lifted board, so a path is
    /// found for every move `destinations` would allow.
    public static func path(of move: Move, in state: GameState) -> MovePath? {
        guard case let .move(pieceID, from, to) = move,
              state.result == .ongoing,
              let piece = state.board.topPiece(from),
              piece.id == pieceID
        else { return nil }

        var lifted = state.board
        lifted.pop(at: from)
        guard !lifted.isEmpty else { return nil }

        switch piece.bug {
        case .queen:
            return groundSlidePath(on: lifted, from: from, to: to, steps: 1)
        case .ant:
            return shortestGroundSlidePath(on: lifted, from: from, to: to)
        case .spider:
            return groundSlidePath(on: lifted, from: from, to: to, steps: 3)
        case .grasshopper:
            return grasshopperPath(on: lifted, from: from, to: to)
        case .beetle:
            return beetlePath(on: lifted, from: from, to: to)
        case .ladybug:
            return ladybugPath(on: lifted, from: from, to: to)
        case .mosquito:
            return mosquitoPath(on: lifted, from: from, to: to)
        case .pillbug:
            return nil
        }
    }

    /// A ground slide of exactly `steps` steps ending at `to`, without ever
    /// revisiting a cell (Queen walks 1, Spider walks 3).
    private static func groundSlidePath(on board: Board, from: Hex, to: Hex, steps: Int) -> MovePath? {
        var route: [Hex] = [from]
        var found: [Hex]?

        func walk(_ hex: Hex, depth: Int) {
            if found != nil { return }
            if depth == steps {
                if hex == to { found = route }
                return
            }
            for next in Rules.groundSlideSteps(on: board, from: hex) where !route.contains(next) {
                route.append(next)
                walk(next, depth: depth + 1)
                route.removeLast()
            }
        }

        walk(from, depth: 0)
        guard let hexes = found else { return nil }
        return MovePath(kind: .slide, steps: hexes.map { MovePath.Step(hex: $0, level: 0) })
    }

    /// The shortest slide route around the hive from `from` to `to` (the Ant).
    /// Breadth-first with parent pointers; every hop respects the same
    /// freedom-to-move gate as `Rules.groundSlideSteps`.
    private static func shortestGroundSlidePath(on board: Board, from: Hex, to: Hex) -> MovePath? {
        var parent: [Hex: Hex] = [from: from]
        var queue: [Hex] = [from]
        var head = 0
        while head < queue.count {
            let hex = queue[head]
            head += 1
            if hex == to { break }
            for next in Rules.groundSlideSteps(on: board, from: hex) where parent[next] == nil {
                parent[next] = hex
                queue.append(next)
            }
        }
        guard parent[to] != nil else { return nil }
        var hexes: [Hex] = [to]
        while let last = hexes.last, last != from {
            hexes.append(parent[last]!)
        }
        hexes.reverse()
        return MovePath(kind: .slide, steps: hexes.map { MovePath.Step(hex: $0, level: 0) })
    }

    /// The straight ray from `from` over the contiguous run of tiles to the
    /// landing cell `to` (the Grasshopper). Intermediates carry the level of
    /// the tile being overflown so the UI can highlight them during the arc.
    private static func grasshopperPath(on board: Board, from: Hex, to: Hex) -> MovePath? {
        for direction in 0..<6 {
            var cursor = from.neighbor(direction)
            guard board.isOccupied(cursor) else { continue }
            var overflown: [Hex] = []
            while board.isOccupied(cursor) {
                overflown.append(cursor)
                cursor = cursor.neighbor(direction)
            }
            guard cursor == to else { continue }
            var steps = [MovePath.Step(hex: from, level: 0)]
            steps += overflown.map { MovePath.Step(hex: $0, level: board.height($0) - 1) }
            steps.append(MovePath.Step(hex: to, level: 0))
            return MovePath(kind: .jump, steps: steps)
        }
        return nil
    }

    /// One step with explicit stack levels at both ends (the Beetle): climbing
    /// up raises `level`, dropping to empty ground returns it to zero.
    private static func beetlePath(on board: Board, from: Hex, to: Hex) -> MovePath? {
        guard from.isAdjacent(to: to) else { return nil }
        return MovePath(kind: .climb, steps: [
            MovePath.Step(hex: from, level: board.height(from)),
            MovePath.Step(hex: to, level: board.height(to)),
        ])
    }

    /// Up onto a tile, across one more tile along the roof, down to the empty
    /// ground beyond (the Ladybug). Mirrors `Rules.ladybugDestinations`.
    private static func ladybugPath(on board: Board, from: Hex, to: Hex) -> MovePath? {
        guard to != from else { return nil }
        for up in board.occupiedNeighbors(from) {
            for over in board.occupiedNeighbors(up) where over != up {
                guard board.emptyNeighbors(over).contains(to) else { continue }
                return MovePath(kind: .overTheTop, steps: [
                    MovePath.Step(hex: from, level: 0),
                    MovePath.Step(hex: up, level: board.height(up)),
                    MovePath.Step(hex: over, level: board.height(over)),
                    MovePath.Step(hex: to, level: 0),
                ])
            }
        }
        return nil
    }

    /// The Mosquito travels like whichever bug it is copying. From atop the
    /// hive it is stuck copying the Beetle (see `destinations`); on the ground
    /// it tries each adjacent bug's route in a fixed order until one reaches
    /// `to` — the same union `Rules.mosquitoGroundDestinations` builds.
    private static func mosquitoPath(on board: Board, from: Hex, to: Hex) -> MovePath? {
        if board.height(from) > 0 {
            return beetlePath(on: board, from: from, to: to)
        }
        let neighborBugs = Set(from.neighbors.compactMap { board.topPiece($0)?.bug }).subtracting([.mosquito])
        for bug in [Bug.queen, .ant, .spider, .grasshopper, .beetle, .ladybug] where neighborBugs.contains(bug) {
            let candidate: MovePath?
            switch bug {
            case .queen: candidate = groundSlidePath(on: board, from: from, to: to, steps: 1)
            case .ant: candidate = shortestGroundSlidePath(on: board, from: from, to: to)
            case .spider: candidate = groundSlidePath(on: board, from: from, to: to, steps: 3)
            case .grasshopper: candidate = grasshopperPath(on: board, from: from, to: to)
            case .beetle: candidate = beetlePath(on: board, from: from, to: to)
            case .ladybug: candidate = ladybugPath(on: board, from: from, to: to)
            default: candidate = nil
            }
            if let candidate { return candidate }
        }
        return nil
    }
}
