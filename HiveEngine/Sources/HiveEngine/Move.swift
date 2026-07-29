import Foundation

/// A single turn's action.
public enum Move: Equatable, Hashable, Codable, Sendable {
    /// Place a tile from hand onto an empty cell.
    case place(Bug, at: Hex)
    /// Move a tile already in play from one cell to another.
    case move(pieceID: Int, from: Hex, to: Hex)
    /// Forfeit the turn (only legal when no placement or move exists).
    case pass
}

/// The outcome of a game.
public enum GameResult: Equatable, Hashable, Codable, Sendable {
    case ongoing
    case win(PlayerColor)
    case draw

    public var isOver: Bool { self != .ongoing }
}
