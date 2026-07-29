import Foundation

/// The two sides. White always moves first.
public enum PlayerColor: String, Codable, Sendable, CaseIterable {
    case white
    case black

    public var opponent: PlayerColor { self == .white ? .black : .white }
}

/// The bug types. The first five are the base game; the last three are the
/// classic expansions (declared here for forward-compatibility).
public enum Bug: String, Codable, Sendable, CaseIterable {
    case queen
    case beetle
    case grasshopper
    case spider
    case ant
    case mosquito
    case ladybug
    case pillbug

    /// The bugs used in the standard base game, in a natural display order.
    public static let baseGame: [Bug] = [.queen, .spider, .beetle, .grasshopper, .ant]

    /// How many of this bug each player owns in the base game.
    public var baseCount: Int {
        switch self {
        case .queen: return 1
        case .spider: return 2
        case .beetle: return 2
        case .grasshopper: return 3
        case .ant: return 3
        case .mosquito, .ladybug, .pillbug: return 1
        }
    }

    public var displayName: String {
        switch self {
        case .queen: return "Queen Bee"
        case .beetle: return "Beetle"
        case .grasshopper: return "Grasshopper"
        case .spider: return "Spider"
        case .ant: return "Soldier Ant"
        case .mosquito: return "Mosquito"
        case .ladybug: return "Ladybug"
        case .pillbug: return "Pillbug"
        }
    }

    /// Single-letter tag used on the tiles.
    public var letter: String {
        switch self {
        case .queen: return "Q"
        case .beetle: return "B"
        case .grasshopper: return "G"
        case .spider: return "S"
        case .ant: return "A"
        case .mosquito: return "M"
        case .ladybug: return "L"
        case .pillbug: return "P"
        }
    }
}

/// A single physical tile. `id` is unique across the whole game so tiles keep a
/// stable identity for animation and history.
public struct Piece: Hashable, Identifiable, Codable, Sendable {
    public let id: Int
    public let bug: Bug
    public let color: PlayerColor

    public init(id: Int, bug: Bug, color: PlayerColor) {
        self.id = id
        self.bug = bug
        self.color = color
    }
}
