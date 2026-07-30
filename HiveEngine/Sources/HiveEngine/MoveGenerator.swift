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
}
