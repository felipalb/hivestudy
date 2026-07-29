import Foundation

/// Low-level movement primitives shared by the move generator.
///
/// Every function here expects the moving tile to have **already been lifted**
/// from `board` (it is "in hand" for the whole move), so `board` represents the
/// static rest of the hive that the tile slides against.
public enum Rules {

    // MARK: Ground sliding (Queen, Spider, Ant, and Beetle at ground level)

    /// Can a tile slide from `hex` across the edge in `direction` to the empty
    /// neighbour there?
    ///
    /// Freedom to move: the destination must be empty and **exactly one** of the
    /// two gate cells must be occupied — one supplies the wall to slide against
    /// (keeping contact with the hive), the other supplies the gap to slip
    /// through. Both occupied ⇒ physically wedged; both empty ⇒ the tile would
    /// detach from the hive mid-slide.
    public static func canGroundSlide(on board: Board, from hex: Hex, direction: Int) -> Bool {
        let dest = hex.neighbor(direction)
        guard !board.isOccupied(dest) else { return false }
        let (g1, g2) = hex.gates(direction)
        let occupiedGates = (board.isOccupied(g1) ? 1 : 0) + (board.isOccupied(g2) ? 1 : 0)
        return occupiedGates == 1
    }

    /// All empty cells a ground-slider can reach in a single step from `hex`.
    public static func groundSlideSteps(on board: Board, from hex: Hex) -> [Hex] {
        (0..<6).compactMap { d in canGroundSlide(on: board, from: hex, direction: d) ? hex.neighbor(d) : nil }
    }

    /// Every cell reachable by sliding any number of steps around the hive
    /// (the Soldier Ant). Breadth-first over single slide steps.
    public static func antReachable(on board: Board, from start: Hex) -> Set<Hex> {
        var visited: Set<Hex> = [start]
        var frontier = [start]
        while let hex = frontier.popLast() {
            for next in groundSlideSteps(on: board, from: hex) where !visited.contains(next) {
                visited.insert(next)
                frontier.append(next)
            }
        }
        visited.remove(start)
        return visited
    }

    /// Every cell reachable by sliding **exactly** `steps` steps without ever
    /// revisiting a cell (the Spider walks 3). Depth-first with a visited path.
    public static func exactSlideDestinations(on board: Board, from start: Hex, steps: Int) -> Set<Hex> {
        var results: Set<Hex> = []
        var path: Set<Hex> = [start]

        func walk(_ hex: Hex, _ depth: Int) {
            if depth == steps {
                results.insert(hex)
                return
            }
            for next in groundSlideSteps(on: board, from: hex) where !path.contains(next) {
                path.insert(next)
                walk(next, depth + 1)
                path.remove(next)
            }
        }

        walk(start, 0)
        return results
    }

    // MARK: Beetle (climbs; height-based gate)

    /// Can a beetle sitting at `hex` move across the edge in `direction`?
    ///
    /// The destination may be empty (drop down / slide) or occupied (climb up).
    /// Height gate: the beetle is blocked only when **both** gate stacks are
    /// taller than both the floor it leaves and the floor it lands on. It must
    /// also stay attached to the hive after landing.
    public static func canBeetleMove(on board: Board, from hex: Hex, direction: Int) -> Bool {
        let dest = hex.neighbor(direction)
        let sourceFloor = board.height(hex)      // tiles left behind (beetle already lifted)
        let destFloor = board.height(dest)       // tiles the beetle will climb onto
        let (g1, g2) = hex.gates(direction)
        let gate = min(board.height(g1), board.height(g2))
        if gate > max(sourceFloor, destFloor) { return false }   // wedged between two walls

        // Stay connected to the hive: climbing onto a stack always keeps contact;
        // dropping to an empty cell requires that cell to touch the hive.
        if destFloor > 0 { return true }
        return board.touchesHive(dest)
    }

    /// All cells a beetle can reach in one move from `hex`.
    public static func beetleDestinations(on board: Board, from hex: Hex) -> [Hex] {
        (0..<6).compactMap { d in canBeetleMove(on: board, from: hex, direction: d) ? hex.neighbor(d) : nil }
    }

    // MARK: Grasshopper (jumps in a straight line)

    /// Landing cells for a grasshopper at `hex`: for each direction with an
    /// immediate occupied neighbour, jump over the contiguous line of tiles to
    /// the first empty cell beyond.
    public static func grasshopperDestinations(on board: Board, from hex: Hex) -> [Hex] {
        var results: [Hex] = []
        for d in 0..<6 {
            var cursor = hex.neighbor(d)
            guard board.isOccupied(cursor) else { continue } // must jump at least one tile
            while board.isOccupied(cursor) { cursor = cursor.neighbor(d) }
            results.append(cursor)
        }
        return results
    }
}
