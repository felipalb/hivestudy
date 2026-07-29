import Foundation

/// A position on a pointy-top hexagonal grid, expressed in axial coordinates.
///
/// The six neighbour directions are ordered so that two indices that are
/// adjacent modulo 6 identify the two hexes that border a shared edge — the
/// "gate" cells used by Hive's freedom-to-move rule.
public struct Hex: Hashable, Sendable, Codable {
    public let q: Int
    public let r: Int

    public init(_ q: Int, _ r: Int) {
        self.q = q
        self.r = r
    }

    public static let origin = Hex(0, 0)

    /// Neighbour offsets, going clockwise: E, NE, NW, W, SW, SE.
    public static let directions: [Hex] = [
        Hex(1, 0),   // 0  E
        Hex(1, -1),  // 1  NE
        Hex(0, -1),  // 2  NW
        Hex(-1, 0),  // 3  W
        Hex(-1, 1),  // 4  SW
        Hex(0, 1)    // 5  SE
    ]

    public static func + (lhs: Hex, rhs: Hex) -> Hex { Hex(lhs.q + rhs.q, lhs.r + rhs.r) }
    public static func - (lhs: Hex, rhs: Hex) -> Hex { Hex(lhs.q - rhs.q, lhs.r - rhs.r) }

    /// The neighbour in the given direction index (wrapped into 0..<6).
    public func neighbor(_ direction: Int) -> Hex {
        self + Hex.directions[((direction % 6) + 6) % 6]
    }

    /// All six neighbours, in direction order.
    public var neighbors: [Hex] { Hex.directions.map { self + $0 } }

    /// The two hexes bordering the edge between `self` and its neighbour in
    /// `direction`. These are the cells that gate a sliding move across that edge.
    public func gates(_ direction: Int) -> (Hex, Hex) {
        let left = self + Hex.directions[(direction + 1) % 6]
        let right = self + Hex.directions[(direction + 5) % 6]
        return (left, right)
    }

    /// The direction index from `self` to an adjacent hex, or `nil` if the hex
    /// is not one of the six neighbours.
    public func direction(to other: Hex) -> Int? {
        Hex.directions.firstIndex(of: other - self)
    }

    /// Whether `other` is one of the six immediate neighbours.
    public func isAdjacent(to other: Hex) -> Bool {
        Hex.directions.contains(other - self)
    }

    /// Hex distance (number of steps between two cells).
    public func distance(to other: Hex) -> Int {
        let dq = q - other.q
        let dr = r - other.r
        return (abs(dq) + abs(dr) + abs(dq + dr)) / 2
    }
}

extension Hex: CustomStringConvertible {
    public var description: String { "(\(q),\(r))" }
}
