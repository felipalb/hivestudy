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
        case .queen: return "Leão"
        case .beetle: return "Gorila"
        case .grasshopper: return "Canguru"
        case .spider: return "Zebra"
        case .ant: return "Guepardo"
        case .mosquito: return "Camaleão"
        case .ladybug: return "Águia"
        case .pillbug: return "Tatu-bola"
        }
    }

    /// Single-letter tag (legacy; the UI now labels tiles with `tileName`).
    public var letter: String {
        switch self {
        case .queen: return "L"
        case .beetle: return "GO"
        case .grasshopper: return "C"
        case .spider: return "Z"
        case .ant: return "G"
        case .mosquito: return "CM"
        case .ladybug: return "A"
        case .pillbug: return "T"
        }
    }

    /// Short, real creature name shown on a tile (the tiles are labelled by
    /// name, not by initial). Concise enough to fit a hexagon at small sizes.
    public var tileName: String {
        switch self {
        case .queen: return "Leão"
        case .beetle: return "Gorila"
        case .grasshopper: return "Canguru"
        case .spider: return "Zebra"
        case .ant: return "Guepardo"
        case .mosquito: return "Camaleão"
        case .ladybug: return "Águia"
        case .pillbug: return "Tatu"
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
