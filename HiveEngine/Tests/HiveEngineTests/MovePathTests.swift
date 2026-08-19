import Testing
@testable import HiveEngine

// MARK: - Helpers

private func mpPiece(_ id: Int, _ bug: HiveEngine.Bug, _ color: PlayerColor) -> Piece {
    Piece(id: id, bug: bug, color: color)
}

private func mpBoard(_ tiles: [(Hex, HiveEngine.Bug, PlayerColor)]) -> Board {
    var b = Board()
    var id = 0
    for (hex, bug, color) in tiles {
        b.push(mpPiece(id, bug, color), at: hex)
        id += 1
    }
    return b
}

/// An assembled mid-game position: queens are treated as already placed (empty
/// hand), so piece movement is available to `current`.
private func mpState(_ tiles: [(Hex, HiveEngine.Bug, PlayerColor)], current: PlayerColor = .white) -> GameState {
    GameState(board: mpBoard(tiles), current: current, unplaced: [], movesMade: [.white: 4, .black: 4])
}

/// Deterministic RNG so the fuzz test is reproducible.
private struct PathRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Validates the structural invariants every path must hold, regardless of bug:
/// endpoints match the move, at least origin+destination, and every consecutive
/// pair of stops is one hex apart.
private func expectWellFormed(_ path: MovePath?, for move: Move, sourceLocation: SourceLocation = #_sourceLocation) {
    guard case let .move(_, from, to) = move else {
        Issue.record("expected a .move", sourceLocation: sourceLocation)
        return
    }
    guard let path else {
        Issue.record("expected a path for \(move)", sourceLocation: sourceLocation)
        return
    }
    #expect(path.from == from, sourceLocation: sourceLocation)
    #expect(path.to == to, sourceLocation: sourceLocation)
    #expect(path.steps.count >= 2, sourceLocation: sourceLocation)
    for pair in zip(path.steps, path.steps.dropFirst()) {
        #expect(pair.0.hex.isAdjacent(to: pair.1.hex),
                "non-adjacent step \(pair.0.hex) -> \(pair.1.hex)",
                sourceLocation: sourceLocation)
    }
}

// MARK: - Ground sliders

@Suite struct SlidePathTests {
    /// Queen at the origin with one wall tile: a slide is exactly one step.
    @Test func queenPathIsOneStep() {
        let state = mpState([
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .ant, .white),
            (Hex(2, 0), .queen, .black),
        ])
        let dests = MoveGenerator.destinations(for: 0, in: state)
        #expect(dests.contains(Hex(1, -1)))

        let move = Move.move(pieceID: 0, from: Hex(0, 0), to: Hex(1, -1))
        let path = MoveGenerator.path(of: move, in: state)
        expectWellFormed(path, for: move)
        #expect(path?.kind == .slide)
        #expect(path?.steps.map(\.hex) == [Hex(0, 0), Hex(1, -1)])
        #expect(path?.steps.allSatisfy { $0.level == 0 } == true)
    }

    /// The ant's route around a 3-tile line: every hop is a legal freedom-to-move
    /// slide, no cell is revisited, and it takes the shortest way (5 hops).
    @Test func antPathIsShortestLegalSlideChain() {
        let state = mpState([
            (Hex(-1, 0), .ant, .white),
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .ant, .black),
            (Hex(2, 0), .queen, .black),
        ])
        let from = Hex(-1, 0)
        let to = Hex(3, 0)
        #expect(MoveGenerator.destinations(for: 0, in: state).contains(to))

        let move = Move.move(pieceID: 0, from: from, to: to)
        let path = MoveGenerator.path(of: move, in: state)
        expectWellFormed(path, for: move)
        #expect(path?.kind == .slide)
        // Shortest route around the line is 5 hops -> 6 stops.
        #expect(path?.steps.count == 6)

        // Every hop obeys the gate rule against the lifted board.
        var lifted = state.board
        lifted.pop(at: from)
        let hexes = path!.steps.map(\.hex)
        #expect(Set(hexes).count == hexes.count, "ant path revisits a cell")
        for pair in zip(hexes, hexes.dropFirst()) {
            let direction = pair.0.direction(to: pair.1)!
            #expect(Rules.canGroundSlide(on: lifted, from: pair.0, direction: direction),
                    "illegal slide hop \(pair.0) -> \(pair.1)")
            #expect(!lifted.isOccupied(pair.1))
        }
    }

    /// The spider always walks exactly three steps, never revisiting a cell.
    @Test func spiderPathWalksExactlyThreeSteps() {
        let state = mpState([
            (Hex(-1, 0), .spider, .white),
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .ant, .black),
            (Hex(2, 0), .queen, .black),
        ])
        let from = Hex(-1, 0)
        for to in MoveGenerator.destinations(for: 0, in: state) {
            let move = Move.move(pieceID: 0, from: from, to: to)
            let path = MoveGenerator.path(of: move, in: state)
            expectWellFormed(path, for: move)
            #expect(path?.kind == .slide)
            #expect(path?.steps.count == 4, "spider walk must be origin + 3 steps")
            let hexes = path!.steps.map(\.hex)
            #expect(Set(hexes).count == 4, "spider revisits a cell")
        }
    }
}

// MARK: - Jumps, climbs, and the roof

@Suite struct JumpClimbPathTests {
    /// The grasshopper's path is the straight ray, carrying every overflown tile.
    @Test func grasshopperPathFliesOverTheLine() {
        let state = mpState([
            (Hex(0, 0), .grasshopper, .white),
            (Hex(1, 0), .ant, .white),
            (Hex(2, 0), .ant, .black),
            (Hex(2, -1), .queen, .black),
        ])
        let move = Move.move(pieceID: 0, from: Hex(0, 0), to: Hex(3, 0))
        #expect(MoveGenerator.destinations(for: 0, in: state).contains(Hex(3, 0)))

        let path = MoveGenerator.path(of: move, in: state)
        expectWellFormed(path, for: move)
        #expect(path?.kind == .jump)
        #expect(path?.steps.map(\.hex) == [Hex(0, 0), Hex(1, 0), Hex(2, 0), Hex(3, 0)])
        // Intermediates are the overflown tiles; endpoints are ground level.
        #expect(path?.steps.first?.level == 0)
        #expect(path?.steps.last?.level == 0)
    }

    /// The beetle's path records the stack level at each end — climbing a
    /// 2-tile stack lands on level 2, dropping to empty ground returns to 0.
    @Test func beetlePathRecordsLevelChange() {
        // Climb up: beetle beside a 2-stack.
        let climbing = mpState([
            (Hex(0, 0), .beetle, .white),
            (Hex(1, 0), .ant, .white),
            (Hex(1, 0), .ant, .black),
            (Hex(10, 0), .queen, .black),
        ])
        let up = MoveGenerator.path(of: .move(pieceID: 0, from: Hex(0, 0), to: Hex(1, 0)), in: climbing)
        expectWellFormed(up, for: .move(pieceID: 0, from: Hex(0, 0), to: Hex(1, 0)))
        #expect(up?.kind == .climb)
        #expect(up?.steps.map(\.level) == [0, 2])

        // Drop down: beetle atop that same stack steps off to empty ground.
        let dropping = mpState([
            (Hex(1, 0), .ant, .white),
            (Hex(1, 0), .ant, .black),
            (Hex(1, 0), .beetle, .white),
            (Hex(10, 0), .queen, .black),
        ])
        #expect(MoveGenerator.destinations(for: 2, in: dropping).contains(Hex(2, 0)))
        let down = MoveGenerator.path(of: .move(pieceID: 2, from: Hex(1, 0), to: Hex(2, 0)), in: dropping)
        expectWellFormed(down, for: .move(pieceID: 2, from: Hex(1, 0), to: Hex(2, 0)))
        #expect(down?.kind == .climb)
        #expect(down?.steps.map(\.level) == [2, 0])
    }

    /// The ladybug goes up, across the roof, then down — four stops with the
    /// roof tiles' levels in between.
    @Test func ladybugPathClimbsTwoAndDrops() {
        let state = mpState([
            (Hex(0, 0), .ladybug, .white),
            (Hex(1, 0), .ant, .white),
            (Hex(1, -1), .ant, .black),
            (Hex(2, -1), .queen, .black),
        ])
        let to = Hex(0, -1)   // empty, adjacent to the roof tile (1,-1)
        #expect(MoveGenerator.destinations(for: 0, in: state).contains(to))

        let move = Move.move(pieceID: 0, from: Hex(0, 0), to: to)
        let path = MoveGenerator.path(of: move, in: state)
        expectWellFormed(path, for: move)
        #expect(path?.kind == .overTheTop)
        #expect(path?.steps.map(\.hex) == [Hex(0, 0), Hex(1, 0), Hex(1, -1), Hex(0, -1)])
        #expect(path?.steps.map(\.level) == [0, 1, 1, 0])
    }

    /// A ground mosquito copies the grasshopper when that is the bug beside it.
    @Test func mosquitoPathCopiesTheAdjacentBug() {
        let state = mpState([
            (Hex(0, 0), .mosquito, .white),
            (Hex(1, 0), .grasshopper, .white),
            (Hex(2, 0), .ant, .black),
            (Hex(2, -1), .queen, .black),
        ])
        let move = Move.move(pieceID: 0, from: Hex(0, 0), to: Hex(3, 0))
        #expect(MoveGenerator.destinations(for: 0, in: state).contains(Hex(3, 0)))

        let path = MoveGenerator.path(of: move, in: state)
        expectWellFormed(path, for: move)
        #expect(path?.kind == .jump)
        #expect(path?.steps.map(\.hex) == [Hex(0, 0), Hex(1, 0), Hex(2, 0), Hex(3, 0)])
    }
}

// MARK: - Non-moves and global coverage

@Suite struct PathCoverageTests {
    @Test func placementsAndPassesHaveNoPath() {
        var state = GameState(config: GameConfig(expansions: [.mosquito, .ladybug]))
        state.apply(.place(.queen, at: .origin))
        #expect(MoveGenerator.path(of: .place(.ant, at: Hex(1, 0)), in: state) == nil)
        #expect(MoveGenerator.path(of: .pass, in: state) == nil)
    }

    /// Every legal piece move in random games must have an animatable
    /// path — the UI depends on it to show how each bug travels.
    @Test func everyLegalMoveHasAPath() {
        var totalPlies = 0
        var rng = PathRNG(seed: 42)
        for _ in 0..<5 {
            var state = GameState(config: GameConfig(expansions: [.mosquito, .ladybug]))
            var plies = 0
            while plies < 160 && state.result == .ongoing {
                let moves = state.legalMoves()
                for move in moves {
                    guard case .move = move else { continue }   // placements/pass have no route
                    expectWellFormed(MoveGenerator.path(of: move, in: state), for: move)
                }
                state.apply(moves[Int(rng.next() % UInt64(moves.count))])
                plies += 1
            }
            totalPlies += plies
            if totalPlies >= 40 { break }
        }
        #expect(totalPlies >= 40, "random games ended too early to exercise movement")
    }
}
