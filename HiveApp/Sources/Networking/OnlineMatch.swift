import Foundation
import HiveEngine

/// Represents the status of an online multiplayer match.
public enum OnlineMatchStatus: String, Codable, Sendable {
    case waitingForOpponent = "waiting"
    case active = "active"
    case finished = "finished"
    case abandoned = "abandoned"
}

/// DTO for a recorded move in Firestore.
public struct OnlineMoveRecord: Codable, Sendable, Identifiable {
    public var id: Int { sequence }
    public let sequence: Int
    public let playerColor: PlayerColor
    public let move: Move
    public let timestamp: Date

    public init(sequence: Int, playerColor: PlayerColor, move: Move, timestamp: Date = Date()) {
        self.sequence = sequence
        self.playerColor = playerColor
        self.move = move
        self.timestamp = timestamp
    }
}

/// The document model for an online match stored in Cloud Firestore.
public struct OnlineMatch: Codable, Identifiable, Sendable {
    public let id: String
    public var roomCode: String?
    public var hostPlayerID: String
    public var hostDisplayName: String
    public var guestPlayerID: String?
    public var guestDisplayName: String?

    public var playerWhiteID: String
    public var playerBlackID: String?

    public var status: OnlineMatchStatus
    public var moves: [OnlineMoveRecord]
    public var config: GameConfig
    public var winnerColor: PlayerColor?
    public var isDraw: Bool
    public var abandonedByPlayerID: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        roomCode: String? = nil,
        hostPlayerID: String,
        hostDisplayName: String,
        guestPlayerID: String? = nil,
        guestDisplayName: String? = nil,
        playerWhiteID: String,
        playerBlackID: String? = nil,
        status: OnlineMatchStatus = .waitingForOpponent,
        moves: [OnlineMoveRecord] = [],
        config: GameConfig = .base,
        winnerColor: PlayerColor? = nil,
        isDraw: Bool = false,
        abandonedByPlayerID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.roomCode = roomCode
        self.hostPlayerID = hostPlayerID
        self.hostDisplayName = hostDisplayName
        self.guestPlayerID = guestPlayerID
        self.guestDisplayName = guestDisplayName
        self.playerWhiteID = playerWhiteID
        self.playerBlackID = playerBlackID
        self.status = status
        self.moves = moves
        self.config = config
        self.winnerColor = winnerColor
        self.isDraw = isDraw
        self.abandonedByPlayerID = abandonedByPlayerID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns which color the given player UID is playing as.
    public func color(for playerID: String) -> PlayerColor? {
        if playerID == playerWhiteID {
            return .white
        } else if playerID == playerBlackID {
            return .black
        }
        return nil
    }

    /// Returns the opponent's display name for the local player.
    public func opponentName(for playerID: String) -> String {
        if playerID == hostPlayerID {
            return guestDisplayName ?? "Oponente"
        } else {
            return hostDisplayName
        }
    }
}
