import Foundation

/// The playing surface. Hive has no fixed board — the tiles themselves form it.
///
/// Each occupied cell holds a stack of one or more tiles (beetles climb on top),
/// stored bottom-to-top.
public struct Board: Codable, Sendable, Equatable {
    /// Occupied cells only. A cell present in the map always has a non-empty stack.
    public private(set) var stacks: [Hex: [Piece]]

    public init(stacks: [Hex: [Piece]] = [:]) {
        self.stacks = stacks
    }

    public var isEmpty: Bool { stacks.isEmpty }

    /// Every occupied cell.
    public var occupiedCells: [Hex] { Array(stacks.keys) }

    /// Total number of tiles in play.
    public var tileCount: Int { stacks.values.reduce(0) { $0 + $1.count } }

    public func isOccupied(_ hex: Hex) -> Bool { stacks[hex]?.isEmpty == false }

    /// Number of tiles stacked at a cell (0 when empty).
    public func height(_ hex: Hex) -> Int { stacks[hex]?.count ?? 0 }

    /// The topmost tile at a cell, if any.
    public func topPiece(_ hex: Hex) -> Piece? { stacks[hex]?.last }

    /// The full stack (bottom-to-top) at a cell.
    public func stack(_ hex: Hex) -> [Piece] { stacks[hex] ?? [] }

    // MARK: Mutation

    /// Drop a tile on top of a cell.
    public mutating func push(_ piece: Piece, at hex: Hex) {
        stacks[hex, default: []].append(piece)
    }

    /// Lift the top tile off a cell, returning it.
    @discardableResult
    public mutating func pop(at hex: Hex) -> Piece? {
        guard var s = stacks[hex], !s.isEmpty else { return nil }
        let piece = s.removeLast()
        if s.isEmpty { stacks[hex] = nil } else { stacks[hex] = s }
        return piece
    }

    // MARK: Queries

    /// Cells adjacent to `hex` that are currently occupied.
    public func occupiedNeighbors(_ hex: Hex) -> [Hex] {
        hex.neighbors.filter { isOccupied($0) }
    }

    /// Cells adjacent to `hex` that are currently empty.
    public func emptyNeighbors(_ hex: Hex) -> [Hex] {
        hex.neighbors.filter { !isOccupied($0) }
    }

    /// Whether a cell touches the hive (has at least one occupied neighbour).
    public func touchesHive(_ hex: Hex) -> Bool {
        hex.neighbors.contains { isOccupied($0) }
    }

    /// Location of a specific tile (searches every stack). O(n); used sparingly.
    public func location(of pieceID: Int) -> Hex? {
        for (hex, stack) in stacks where stack.contains(where: { $0.id == pieceID }) {
            return hex
        }
        return nil
    }

    // MARK: Connectivity (One-Hive rule)

    /// Whether the whole hive is a single connected group, considering only the
    /// footprint of occupied cells (stacking is irrelevant to connectivity).
    public func isConnected() -> Bool {
        connectedComponentCount(excluding: nil) <= 1
    }

    /// True when removing the tile on top of `hex` would split the hive.
    ///
    /// Only meaningful for a ground tile (height 1): a tile sitting on top of a
    /// stack never affects the footprint, so it can never be a cut vertex.
    public func isCutVertex(_ hex: Hex) -> Bool {
        guard height(hex) == 1 else { return false }
        return connectedComponentCount(excluding: hex) > 1
    }

    /// Number of connected components of the occupied footprint, optionally
    /// pretending `excluded` is empty.
    func connectedComponentCount(excluding excluded: Hex?) -> Int {
        var remaining = Set(stacks.keys)
        if let excluded { remaining.remove(excluded) }
        guard let start = remaining.first else { return 0 }

        var components = 0
        while let seed = remaining.first {
            components += 1
            if components > 1 { return components }
            var stack = [seed]
            remaining.remove(seed)
            while let current = stack.popLast() {
                for neighbor in current.neighbors where remaining.contains(neighbor) {
                    remaining.remove(neighbor)
                    stack.append(neighbor)
                }
            }
        }
        _ = start
        return components
    }
}
