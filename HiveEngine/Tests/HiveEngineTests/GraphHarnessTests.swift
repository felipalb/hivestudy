import Testing
@testable import HiveEngine

// MARK: - Graph-Engineering Test Harness
//
// Companion to the Obsidian vault in `HiveApp/Graph/HiveVault`. Each suite here
// realises one graph-testing technique documented there:
//
//   • PerftTests            → 40-Conceitos-Grafo/Perft            (game-tree enumeration)
//   • MetamorphicTests      → 40-Conceitos-Grafo/Teste Metamórfico (60° rotation symmetry)
//   • PropertyInvariantTests→ 40-Conceitos-Grafo/Teste por Propriedades
//
// These close the gaps flagged in `00-Central/Matriz de Rastreabilidade`.

// MARK: Local helpers (file-private; independent from the main test file)

private func harnessPiece(_ id: Int, _ bug: HiveEngine.Bug, _ color: PlayerColor) -> Piece {
    Piece(id: id, bug: bug, color: color)
}

/// Deterministic xorshift RNG so every property/fuzz run is reproducible.
private struct HarnessRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Rotate an axial hex 60° counter-clockwise about the origin. This is a
/// symmetry of the hex lattice: it maps neighbours→neighbours and gates→gates,
/// so any rule that depends only on relative occupancy is invariant under it.
/// (cube (x,y,z) → (-y,-z,-x), with x=q, z=r, y=-q-r.)
private func rotated60(_ h: Hex) -> Hex {
    let x = h.q, z = h.r, y = -x - z
    return Hex(-y, -x)   // new q = -y, new r = -x
}

/// A random *connected* footprint of `count` cells, filled with dummy white ants.
/// Grown by repeatedly attaching a random empty neighbour, so One-Hive holds.
private func randomConnectedBoard(count: Int, rng: inout HarnessRNG) -> Board {
    var occupied: Set<Hex> = [.origin]
    var guardrail = 0
    while occupied.count < count && guardrail < count * 50 {
        guardrail += 1
        let cells = Array(occupied)
        let base = cells[Int(rng.next() % UInt64(cells.count))]
        let empties = base.neighbors.filter { !occupied.contains($0) }
        guard !empties.isEmpty else { continue }
        occupied.insert(empties[Int(rng.next() % UInt64(empties.count))])
    }
    var b = Board()
    var id = 0
    for h in occupied.sorted(by: { ($0.q, $0.r) < ($1.q, $1.r) }) {
        b.push(harnessPiece(id, .ant, .white), at: h)
        id += 1
    }
    return b
}

// MARK: - Perft (game-tree node enumeration)

enum Perft {
    /// Number of distinct legal move *sequences* of exactly `depth` plies from
    /// `state`. A terminal node contributes 0 continuations (its `legalMoves`
    /// is empty). See vault: `Perft`, `Árvore de Jogo`.
    static func nodes(_ state: GameState, depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = state.legalMoves()
        if depth == 1 { return moves.count }
        var total = 0
        for m in moves { total += nodes(state.applying(m), depth: depth - 1) }
        return total
    }

    /// Per-root-move breakdown — the classic "divide perft" used to localise a
    /// move-generation divergence to a single opening move.
    static func divide(_ state: GameState, depth: Int) -> [(move: Move, count: Int)] {
        state.legalMoves().map { ($0, nodes(state.applying($0), depth: depth - 1)) }
    }
}

@Suite struct PerftTests {

    /// Depth 1 is, by definition, the legal-move count. On the empty board the
    /// five distinct base bugs are placeable on the single origin cell.
    @Test func depth1CountsOpeningMoves() {
        let start = GameState()
        #expect(Perft.nodes(start, depth: 1) == start.legalMoves().count)
        #expect(Perft.nodes(start, depth: 1) == 5)
    }

    /// Depth 2: after any of White's 5 openings, Black may place any of 5 bugs on
    /// any of the opening tile's 6 sides → 5 × (5 × 6) = 150.
    @Test func depth2CountsSecondPly() {
        #expect(Perft.nodes(GameState(), depth: 2) == 150)
    }

    /// Structural invariant (no magic number): the divide-perft breakdown must
    /// sum back to the plain perft. Catches recursion/aggregation bugs.
    @Test func dividePerftSumsToTotal() {
        let start = GameState()
        for depth in 2...3 {
            let whole = Perft.nodes(start, depth: depth)
            let parts = Perft.divide(start, depth: depth).reduce(0) { $0 + $1.count }
            #expect(whole == parts)
        }
    }

    /// Golden regression baseline (base game, no expansions). Captured from the
    /// current engine; a change here means the move generator's behaviour moved.
    @Test func goldenRegressionBaseline() {
        #expect(Perft.nodes(GameState(), depth: 1) == 5)
        #expect(Perft.nodes(GameState(), depth: 2) == 150)
        #expect(Perft.nodes(GameState(), depth: 3) == PERFT_DEPTH_3)
    }
}

/// Captured baseline for the base game (no expansions), White to move from the
/// empty board. perft(1)=5, perft(2)=150, perft(3)=2220. A change to any of
/// these means `MoveGenerator` behaviour moved — investigate before updating.
private let PERFT_DEPTH_3 = 2220

// MARK: - Metamorphic tests (60° rotation symmetry)

@Suite struct MetamorphicTests {

    /// Rotating the whole board 60° must rotate the Ant's BFS reachable set
    /// identically — sliding rules are lattice-symmetric. See vault:
    /// `Teste Metamórfico`, `MEC-Ant Reachable (BFS)`.
    @Test func antReachabilityIsRotationInvariant() {
        var rng = HarnessRNG(seed: 0xA17)
        for _ in 0..<40 {
            let board = randomConnectedBoard(count: 6, rng: &rng)
            // Start from an empty cell touching the hive.
            let perimeter = Set(board.occupiedCells.flatMap { board.emptyNeighbors($0) })
            guard let start = perimeter.sorted(by: { ($0.q, $0.r) < ($1.q, $1.r) }).first else { continue }

            let original = Rules.antReachable(on: board, from: start)

            // Rotate every occupied cell and the start, then recompute.
            var rotatedBoard = Board()
            var id = 0
            for h in board.occupiedCells {
                rotatedBoard.push(harnessPiece(id, .ant, .white), at: rotated60(h)); id += 1
            }
            let rotatedResult = Rules.antReachable(on: rotatedBoard, from: rotated60(start))

            #expect(rotatedResult == Set(original.map(rotated60)))
        }
    }

    /// The same relation for single-step ground slides (Queen granularity).
    @Test func groundSlideStepsAreRotationInvariant() {
        var rng = HarnessRNG(seed: 0xB33)
        for _ in 0..<40 {
            let board = randomConnectedBoard(count: 5, rng: &rng)
            let perimeter = Set(board.occupiedCells.flatMap { board.emptyNeighbors($0) })
            guard let start = perimeter.sorted(by: { ($0.q, $0.r) < ($1.q, $1.r) }).first else { continue }

            let original = Set(Rules.groundSlideSteps(on: board, from: start))
            var rotatedBoard = Board()
            var id = 0
            for h in board.occupiedCells {
                rotatedBoard.push(harnessPiece(id, .ant, .white), at: rotated60(h)); id += 1
            }
            let rotated = Set(Rules.groundSlideSteps(on: rotatedBoard, from: rotated60(start)))
            #expect(rotated == Set(original.map(rotated60)))
        }
    }

    /// rotated60 is a bijection of period 6 (six applications = identity) — a
    /// self-check that the metamorphic transformation itself is sound.
    @Test func rotationHasPeriodSix() {
        for h in [Hex.origin] + Hex.origin.neighbors + [Hex(2, -3), Hex(-4, 1)] {
            var cur = h
            for _ in 0..<6 { cur = rotated60(cur) }
            #expect(cur == h)
        }
    }
}

// MARK: - Property / invariant tests (self-play fuzz)

@Suite struct PropertyInvariantTests {

    /// Walk many seeded random games; assert a bundle of invariants at *every*
    /// ongoing ply. Expands `SelfPlayTests` with the relations documented in
    /// `Teste por Propriedades`.
    @Test func invariantsHoldThroughoutRandomGames() {
        for seed in UInt64(1)...30 {
            var rng = HarnessRNG(seed: seed &* 0x2545F4914F6CDD1D)
            var state = GameState()
            var plies = 0
            while state.result == .ongoing && plies < 80 {
                let moves = state.legalMoves()

                // INV-1 (REQ-07): a game in progress always has at least `.pass`.
                #expect(!moves.isEmpty)

                // INV-2 (REQ-07 contract): `.pass` is offered ONLY when it is the
                // sole legal move.
                if moves.contains(.pass) { #expect(moves == [.pass]) }

                // INV-3 (MEC-Cut Vertex): any of the current player's ground tiles
                // that is an articulation point has zero legal destinations.
                for hex in state.board.occupiedCells {
                    guard let top = state.board.topPiece(hex),
                          top.color == state.current,
                          state.board.height(hex) == 1,
                          state.board.isCutVertex(hex)
                    else { continue }
                    #expect(MoveGenerator.destinations(for: top.id, in: state).isEmpty)
                }

                // INV-4: applying a move is deterministic / side-effect free.
                let move = moves[Int(rng.next() % UInt64(moves.count))]
                #expect(state.applying(move) == state.applying(move))

                state.apply(move)
                plies += 1

                // INV-5 (REQ-01): One-Hive connectivity survives every ply.
                if state.board.tileCount >= 2 { #expect(state.board.isConnected()) }
            }
        }
    }

    /// Metamorphic round-trip at the board level: lifting the top tile off a cell
    /// and dropping it straight back yields an identical board (`Board: Equatable`).
    /// See vault: `Teste Metamórfico`, `COD-Board`.
    @Test func liftAndReplaceIsIdentity() {
        var rng = HarnessRNG(seed: 0x0DDBA11)
        var state = GameState()
        for _ in 0..<40 where state.result == .ongoing {
            let moves = state.legalMoves()
            state.apply(moves[Int(rng.next() % UInt64(moves.count))])
            guard let hex = state.board.occupiedCells.first else { continue }
            var b = state.board
            let lifted = b.pop(at: hex)
            if let lifted { b.push(lifted, at: hex) }
            #expect(b == state.board)
        }
    }

    /// The move generator never emits an illegal move: every reported move
    /// round-trips back through `legalMoves`. (Generator ↔ validator.)
    /// `isLegal` is O(n) per move, so this is O(n²) per ply — kept to a short
    /// horizon on purpose to stay fast (see CLAUDE.md on test speed).
    @Test func generatedMovesAreAllLegal() {
        for seed in UInt64(1)...5 {
            var rng = HarnessRNG(seed: seed &* 0x9E3779B1)
            var state = GameState()
            var plies = 0
            while state.result == .ongoing && plies < 35 {
                let moves = state.legalMoves()
                for m in moves { #expect(state.isLegal(m)) }
                state.apply(moves[Int(rng.next() % UInt64(moves.count))])
                plies += 1
            }
        }
    }
}
