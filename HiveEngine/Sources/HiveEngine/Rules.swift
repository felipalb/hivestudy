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

    // MARK: Ladybug (over the top: up, over, then down — exactly three steps)

    /// Destinations for a Ladybug at `start` (already lifted from `board`).
    ///
    /// It moves **exactly three steps**: the first two *on top of* the hive —
    /// each onto an occupied cell — and the third *down* into an empty cell that
    /// still touches the hive. It never ends on top. While crossing the top it
    /// is **not** subject to the freedom-to-move gate (it walks over the tiles
    /// rather than squeezing between them). It may not finish back on its own
    /// starting cell.
    public static func ladybugDestinations(on board: Board, from start: Hex) -> Set<Hex> {
        var results: Set<Hex> = []
        for up in board.occupiedNeighbors(start) {                      // step 1: climb onto a tile
            for over in board.occupiedNeighbors(up) where over != up {  // step 2: cross to another tile
                for down in board.emptyNeighbors(over) where down != start {  // step 3: drop to empty ground
                    results.insert(down)
                }
            }
        }
        return results
    }

    // MARK: Mosquito (copies an adjacent tile's ability)

    /// Destinations for a mosquito sitting at ground level: the union of every
    /// move a Queen/Ant/Spider/Grasshopper/Beetle would have from `hex`, for each
    /// distinct bug type touching it (a mosquito never copies another mosquito).
    /// A mosquito that has climbed onto the hive by copying a Beetle is *not*
    /// routed here — see `MoveGenerator`, which instead calls
    /// `beetleDestinations` directly once it is on top.
    public static func mosquitoGroundDestinations(on board: Board, from hex: Hex) -> Set<Hex> {
        let neighborBugs = Set(hex.neighbors.compactMap { board.topPiece($0)?.bug }).subtracting([.mosquito])

        var results: Set<Hex> = []
        for bug in neighborBugs {
            switch bug {
            case .queen: results.formUnion(groundSlideSteps(on: board, from: hex))
            case .ant: results.formUnion(antReachable(on: board, from: hex))
            case .spider: results.formUnion(exactSlideDestinations(on: board, from: hex, steps: 3))
            case .grasshopper: results.formUnion(grasshopperDestinations(on: board, from: hex))
            case .beetle: results.formUnion(beetleDestinations(on: board, from: hex))
            case .ladybug: results.formUnion(ladybugDestinations(on: board, from: hex))
            case .mosquito, .pillbug: break // mosquito is never copyable; pillbug has no move yet
            }
        }
        return results
    }
}
