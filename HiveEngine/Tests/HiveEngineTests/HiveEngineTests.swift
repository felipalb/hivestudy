import Testing
@testable import HiveEngine

// MARK: - Helpers

private func piece(_ id: Int, _ bug: HiveEngine.Bug, _ color: PlayerColor) -> Piece {
    Piece(id: id, bug: bug, color: color)
}

/// Build a board from (hex, bug, color) tuples, pushing in order (later tuples
/// stack on top of earlier ones at the same cell).
private func board(_ tiles: [(Hex, HiveEngine.Bug, PlayerColor)]) -> Board {
    var b = Board()
    var id = 0
    for (hex, bug, color) in tiles {
        b.push(piece(id, bug, color), at: hex)
        id += 1
    }
    return b
}

/// Deterministic RNG so the self-play fuzz test is reproducible.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Hex geometry

@Suite struct HexTests {
    @Test func gatesAreTheTwoSharedNeighbors() {
        // Edge from origin going East (dir 0): the shared neighbours are NE and SE.
        let (g1, g2) = Hex.origin.gates(0)
        #expect(Set([g1, g2]) == Set([Hex(1, -1), Hex(0, 1)]))
    }

    @Test func neighborRoundTrip() {
        for d in 0..<6 {
            let n = Hex.origin.neighbor(d)
            #expect(Hex.origin.direction(to: n) == d)
            #expect(Hex.origin.isAdjacent(to: n))
        }
    }
}

// MARK: - Connectivity / One-Hive

@Suite struct ConnectivityTests {
    @Test func middleOfLineIsCutVertex() {
        let b = board([
            (Hex(0, 0), .ant, .white),
            (Hex(1, 0), .ant, .white),
            (Hex(2, 0), .ant, .white)
        ])
        #expect(b.isCutVertex(Hex(1, 0)))       // removing the middle splits the line
        #expect(!b.isCutVertex(Hex(0, 0)))      // an endpoint does not
        #expect(!b.isCutVertex(Hex(2, 0)))
        #expect(b.isConnected())
    }

    @Test func beetleOnTopIsNeverACutVertex() {
        var b = board([(Hex(0, 0), .ant, .white), (Hex(1, 0), .ant, .white)])
        b.push(piece(99, .beetle, .black), at: Hex(0, 0)) // beetle climbs onto (0,0)
        #expect(!b.isCutVertex(Hex(0, 0)))              // footprint unchanged
        #expect(b.height(Hex(0, 0)) == 2)
    }
}

// MARK: - Sliding freedom to move

@Suite struct SlideTests {
    @Test func wedgedBetweenTwoTilesCannotSlide() {
        // Both gate cells occupied -> physically wedged.
        let b = board([(Hex(1, -1), .ant, .white), (Hex(0, 1), .ant, .white)])
        #expect(!Rules.canGroundSlide(on: b, from: .origin, direction: 0))
    }

    @Test func oneOpenGateCanSlide() {
        let b = board([(Hex(1, -1), .ant, .white)]) // only one gate occupied
        #expect(Rules.canGroundSlide(on: b, from: .origin, direction: 0))
    }

    @Test func detachedSlideIsIllegal() {
        // Neither gate occupied -> would break contact with the hive.
        let b = board([(Hex(2, 0), .ant, .white)])
        #expect(!Rules.canGroundSlide(on: b, from: .origin, direction: 0))
    }

    @Test func occupiedDestinationBlocksSlide() {
        let b = board([(Hex(1, 0), .ant, .white), (Hex(1, -1), .ant, .white)])
        #expect(!Rules.canGroundSlide(on: b, from: .origin, direction: 0))
    }
}

// MARK: - Spider and Ant

@Suite struct SpiderAntTests {
    // A two-tile "domino" hive; the mover starts at (2,0).
    private var domino: Board {
        board([(Hex(0, 0), .ant, .white), (Hex(1, 0), .ant, .white)])
    }

    @Test func spiderWalksExactlyThreeSteps() {
        let dests = Rules.exactSlideDestinations(on: domino, from: Hex(2, 0), steps: 3)
        #expect(dests == Set([Hex(0, -1), Hex(-1, 1)]))
    }

    @Test func antReachesWholePerimeter() {
        let dests = Rules.antReachable(on: domino, from: Hex(2, 0))
        #expect(dests.count == 7)                     // every ring cell except the start
        #expect(!dests.contains(Hex(2, 0)))
    }

    @Test func spiderIsSubsetOfAnt() {
        let spider = Rules.exactSlideDestinations(on: domino, from: Hex(2, 0), steps: 3)
        let ant = Rules.antReachable(on: domino, from: Hex(2, 0))
        #expect(spider.isSubset(of: ant))
    }

    @Test func oneStepMatchesGroundSlideSteps() {
        let step1 = Rules.exactSlideDestinations(on: domino, from: Hex(2, 0), steps: 1)
        let direct = Set(Rules.groundSlideSteps(on: domino, from: Hex(2, 0)))
        #expect(step1 == direct)
    }
}

// MARK: - Beetle

@Suite struct BeetleTests {
    @Test func beetleGateBlocksBetweenTwoStacks() {
        // Two height-2 stacks flank the edge; a ground beetle cannot pass between.
        var b = Board()
        for cell in [Hex(1, -1), Hex(0, 1)] {
            b.push(piece(0, .ant, .white), at: cell)
            b.push(piece(1, .beetle, .black), at: cell)
        }
        #expect(!Rules.canBeetleMove(on: b, from: .origin, direction: 0))
    }

    @Test func beetleClimbsOntoAdjacentTile() {
        let b = board([(Hex(1, 0), .ant, .white)]) // destination has a tile
        #expect(Rules.canBeetleMove(on: b, from: .origin, direction: 0))
    }

    @Test func beetleGateOpensWhenLowEnough() {
        // Flanking stacks of height 1 do not block a ground-to-ground beetle step.
        let b = board([(Hex(1, -1), .ant, .white)]) // single tile, one gate
        #expect(Rules.canBeetleMove(on: b, from: .origin, direction: 0))
    }
}

// MARK: - Grasshopper

@Suite struct GrasshopperTests {
    @Test func jumpsOverContiguousLine() {
        let b = board([(Hex(1, 0), .ant, .white), (Hex(2, 0), .ant, .white)])
        let dests = Rules.grasshopperDestinations(on: b, from: .origin)
        #expect(dests == [Hex(3, 0)])   // lands just past the line
    }

    @Test func cannotJumpWithoutAdjacentTile() {
        let b = board([(Hex(3, 0), .ant, .white)]) // gap in front, nothing to jump
        let dests = Rules.grasshopperDestinations(on: b, from: .origin)
        #expect(dests.isEmpty)
    }
}

// MARK: - Ladybug (three steps: up, over, down)

@Suite struct LadybugTests {
    // A two-tile "domino" hive; the ladybug starts at (2,0) touching it.
    private var domino: Board {
        board([(Hex(0, 0), .ant, .white), (Hex(1, 0), .ant, .white)])
    }

    @Test func climbsOverTheHiveAndDropsDown() {
        // From (2,0) it must climb onto (1,0), cross to (0,0), then drop into one
        // of (0,0)'s five empty sides. Every landing is empty ground, never a
        // cell it climbed over.
        let dests = Rules.ladybugDestinations(on: domino, from: Hex(2, 0))
        #expect(dests == Set([Hex(1, -1), Hex(0, -1), Hex(-1, 0), Hex(-1, 1), Hex(0, 1)]))
        #expect(!dests.contains(Hex(0, 0)))   // never ends on top of a tile
        #expect(!dests.contains(Hex(1, 0)))
        #expect(!dests.contains(Hex(2, 0)))   // never returns to its own start
    }

    @Test func needsTwoTilesToWalkOver() {
        // A single lone tile: the ladybug can climb up but has nowhere to cross to.
        let b = board([(Hex(0, 0), .ant, .white)])
        #expect(Rules.ladybugDestinations(on: b, from: Hex(1, 0)).isEmpty)
    }

    @Test func generatorRoutesLadybugAndRespectsOneHive() {
        // A real state: white ladybug on the end of a line, white Queen down so
        // pieces may move. The generator must produce the over-the-top landings.
        let b = board([
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .ant, .white),
            (Hex(2, 0), .ladybug, .white)
        ])
        let state = GameState(board: b, current: .white,
                              unplaced: [], movesMade: [.white: 3, .black: 3])
        var lifted = b
        lifted.pop(at: Hex(2, 0))
        let expected = Rules.ladybugDestinations(on: lifted, from: Hex(2, 0))
        #expect(!expected.isEmpty)
        #expect(Set(MoveGenerator.destinations(for: 2, in: state)) == expected)
    }

    @Test func mosquitoCanCopyLadybug() {
        // Mosquito (lifted, at origin) touches a ladybug at (1,0); it should gain
        // the ladybug's over-the-top destinations.
        let b = board([(Hex(1, 0), .ladybug, .white), (Hex(2, 0), .ant, .white)])
        let dests = Rules.mosquitoGroundDestinations(on: b, from: .origin)
        #expect(!dests.isEmpty)
        #expect(dests == Rules.ladybugDestinations(on: b, from: .origin))
    }
}

// MARK: - Tutorial finish-drill geometry (guards the app's scripted win board)

@Suite struct TutorialScenarioTests {
    /// The guided tutorial's final drill hands White a Grasshopper that jumps
    /// into the last open side of Black's Queen to win. The app rebuilds this
    /// exact board; this test guards the hand-computed coordinates.
    @Test func grasshopperJumpCompletesTheSurround() {
        let b = board([
            (Hex(0, 0), .queen, .black),        // id 0 — Black Queen, 5 sides filled
            (Hex(1, 0), .ant, .black),          // id 1  (E)
            (Hex(1, -1), .beetle, .white),      // id 2  (NE)
            (Hex(0, -1), .spider, .black),      // id 3  (NW)
            (Hex(-1, 1), .ant, .white),         // id 4  (SW)
            (Hex(0, 1), .grasshopper, .black),  // id 5  (SE)
            (Hex(1, 1), .queen, .white),        // id 6  — White Queen (so White may move)
            (Hex(2, 0), .grasshopper, .white)   // id 7  — the winning mover
        ])
        let state = GameState(board: b, current: .white,
                              unplaced: [], movesMade: [.white: 5, .black: 5])
        #expect(state.result == .ongoing)
        #expect(state.queenSurroundCount(.black) == 5)         // gap at (-1,0)

        let dests = MoveGenerator.destinations(for: 7, in: state)
        #expect(dests.contains(Hex(-1, 0)))                    // the winning jump

        let after = state.applying(.move(pieceID: 7, from: Hex(2, 0), to: Hex(-1, 0)))
        #expect(after.result == .win(.white))
    }
}

// MARK: - Mosquito (copies an adjacent tile's ability)

@Suite struct MosquitoTests {
    @Test func copiesAdjacentAntAbility() {
        // Same domino shape as the Ant tests, but the mover copies it as a mosquito.
        let b = board([(Hex(0, 0), .ant, .white), (Hex(1, 0), .ant, .white)])
        let dests = Rules.mosquitoGroundDestinations(on: b, from: Hex(2, 0))
        #expect(dests == Rules.antReachable(on: b, from: Hex(2, 0)))
    }

    @Test func copiesAdjacentGrasshopperAbility() {
        let b = board([(Hex(1, 0), .grasshopper, .white), (Hex(2, 0), .ant, .white)])
        let dests = Rules.mosquitoGroundDestinations(on: b, from: .origin)
        #expect(dests == Set(Rules.grasshopperDestinations(on: b, from: .origin)))
        #expect(dests == [Hex(3, 0)])
    }

    @Test func unionsAllDistinctNeighborAbilities() {
        // Touches an Ant (E) and, along a separate line, a Grasshopper (SE) with
        // another tile to jump over — the mosquito should get *both* abilities.
        let b = board([
            (Hex(1, 0), .ant, .white),
            (Hex(0, 1), .grasshopper, .white),
            (Hex(0, 2), .ant, .black)
        ])
        let dests = Rules.mosquitoGroundDestinations(on: b, from: .origin)
        let antPart = Rules.antReachable(on: b, from: .origin)
        let hopperPart = Set(Rules.grasshopperDestinations(on: b, from: .origin))
        #expect(!antPart.isEmpty && !hopperPart.isEmpty)
        #expect(dests == antPart.union(hopperPart))
    }

    @Test func neverCopiesAnotherMosquito() {
        let b = board([(Hex(1, 0), .mosquito, .white)])
        #expect(Rules.mosquitoGroundDestinations(on: b, from: .origin).isEmpty)
    }

    @Test func atopHiveMosquitoMovesOnlyAsBeetle() {
        // A mosquito that climbed onto an ant (by having earlier copied a Beetle)
        // is now itself atop the hive — from here on it can only move as a Beetle,
        // regardless of what it currently touches.
        var b = board([(Hex(0, 0), .queen, .black), (Hex(1, 0), .ant, .black)])
        b.push(piece(50, .mosquito, .black), at: Hex(1, 0))
        let state = GameState(board: b, current: .black,
                              unplaced: [], movesMade: [.white: 3, .black: 3])

        var lifted = b
        lifted.pop(at: Hex(1, 0))
        let expected = Set(Rules.beetleDestinations(on: lifted, from: Hex(1, 0)))

        #expect(Set(MoveGenerator.destinations(for: 50, in: state)) == expected)
    }
}

// MARK: - Placement rules (via GameState)

@Suite struct PlacementTests {
    @Test func firstMoveGoesToOrigin() {
        let state = GameState()
        #expect(MoveGenerator.placementCells(state) == [.origin])
        // Five distinct base bugs are placeable on the opening move.
        #expect(MoveGenerator.legalPlacements(state).count == 5)
    }

    @Test func secondPlayerPlacesAdjacentToOpponent() {
        var state = GameState()
        state.apply(.place(.ant, at: .origin))       // white opens
        let cells = Set(MoveGenerator.placementCells(state))
        #expect(cells == Set(Hex.origin.neighbors))  // black may place on any of 6 sides
    }

    @Test func cannotPlaceNextToEnemyAfterOpening() {
        var state = GameState()
        state.apply(.place(.ant, at: .origin))        // white @ (0,0)
        state.apply(.place(.ant, at: Hex(1, 0)))      // black @ (1,0)
        // White now may only place touching white and NOT touching black.
        let cells = Set(MoveGenerator.placementCells(state))
        #expect(!cells.isEmpty)
        for cell in cells {
            #expect(cell.neighbors.allSatisfy { state.board.topPiece($0)?.color != .black })
            #expect(cell.neighbors.contains { state.board.topPiece($0)?.color == .white })
        }
    }

    @Test func queenMustBePlacedByFourthTurn() {
        // Constructed position: white has taken 3 turns, no Queen yet.
        let b = board([
            (Hex(0, 0), .ant, .white), (Hex(1, 0), .ant, .black),
            (Hex(-1, 0), .spider, .white), (Hex(2, 0), .ant, .black),
            (Hex(-2, 0), .beetle, .white), (Hex(3, 0), .spider, .black)
        ])
        let whiteUnplaced = [piece(100, .queen, .white), piece(101, .ant, .white)]
        let state = GameState(board: b, current: .white,
                              unplaced: whiteUnplaced,
                              movesMade: [.white: 3, .black: 3])
        #expect(state.mustPlaceQueen)
        let placements = MoveGenerator.legalPlacements(state)
        #expect(!placements.isEmpty)
        for move in placements {
            if case let .place(bug, _) = move { #expect(bug == .queen) }
        }
        // And no tile may move while the Queen is still in hand.
        #expect(MoveGenerator.legalPieceMoves(state).isEmpty)
    }
}

// MARK: - Beetle pinning (via generator)

@Suite struct PinningTests {
    @Test func pinnedTileHasNoMoves() {
        // Black beetle sits on top of a black ant; the ant is pinned.
        var b = board([(Hex(0, 0), .queen, .black), (Hex(1, 0), .ant, .black)])
        b.push(piece(50, .beetle, .black), at: Hex(1, 0))
        let state = GameState(board: b, current: .black,
                              unplaced: [], movesMade: [.white: 3, .black: 3])
        // The ant (id 1) is buried and cannot move.
        #expect(MoveGenerator.destinations(for: 1, in: state).isEmpty)
        // The beetle on top (id 50) can move.
        #expect(!MoveGenerator.destinations(for: 50, in: state).isEmpty)
    }
}

// MARK: - Win detection

@Suite struct WinTests {
    @Test func surroundingWhiteQueenIsBlackWin() {
        var b = Board()
        b.push(piece(0, .queen, .white), at: .origin)
        var id = 10
        for n in Hex.origin.neighbors {
            b.push(piece(id, .ant, id.isMultiple(of: 2) ? .black : .white), at: n)
            id += 1
        }
        let state = GameState(board: b, current: .white,
                              unplaced: [], movesMade: [.white: 6, .black: 6])
        #expect(state.result == .win(.black))
        #expect(state.queenSurroundCount(.white) == 6)
    }

    @Test func bothQueensSurroundedIsDraw() {
        var b = Board()
        b.push(piece(0, .queen, .white), at: .origin)
        b.push(piece(1, .queen, .black), at: Hex(10, 0))
        var id = 20
        for n in Hex.origin.neighbors + Hex(10, 0).neighbors {
            b.push(piece(id, .ant, .white), at: n)
            id += 1
        }
        let state = GameState(board: b, current: .white,
                              unplaced: [], movesMade: [.white: 8, .black: 8])
        #expect(state.result == .draw)
    }
}

// MARK: - Self-play fuzz (invariants)

@Suite struct SelfPlayTests {
    @Test func randomGamesKeepTheHiveConnected() {
        for seed in UInt64(1)...20 {
            var rng = SeededRNG(seed: seed)
            var state = GameState()
            var plies = 0
            while state.result == .ongoing && plies < 60 {
                let moves = state.legalMoves()
                #expect(!moves.isEmpty)                 // always at least .pass
                let move = moves[Int(rng.next() % UInt64(moves.count))]
                state.apply(move)
                plies += 1
                if state.board.tileCount >= 2 {
                    #expect(state.board.isConnected())  // One-Hive invariant holds
                }
            }
        }
    }
}

// MARK: - AI

@Suite struct AITests {
    /// The medium AI (2-ply search) should dominate a random mover: never lose,
    /// and win a clear majority of games.
    @Test func aiBeatsRandomPlayer() {
        var wins = 0, losses = 0
        let games = 8
        for seed in UInt64(1)...UInt64(games) {
            var rng = SeededRNG(seed: seed &* 2_654_435_761)
            var state = GameState()
            // AI plays White on even seeds, Black on odd, to test both sides.
            let aiColor: PlayerColor = seed.isMultiple(of: 2) ? .white : .black
            var plies = 0
            while state.result == .ongoing && plies < 120 {
                let move: Move
                if state.current == aiColor {
                    move = HiveAI.bestMove(for: state, difficulty: .medium,
                                           timeLimit: 5, rng: &rng) ?? .pass
                } else {
                    let legal = state.legalMoves()
                    move = legal[Int(rng.next() % UInt64(legal.count))]
                }
                #expect(state.legalMoves().contains(move)) // AI never returns an illegal move
                state.apply(move)
                plies += 1
            }
            if state.result == .win(aiColor) { wins += 1 }
            if state.result == .win(aiColor.opponent) { losses += 1 }
        }
        #expect(losses == 0)   // random should never beat the search
        #expect(wins >= 4)     // and the AI wins most games outright
    }

    @Test func aiTakesAnImmediateWin() {
        // White queen needs one more tile to be surrounded; Black to move can win.
        var b = Board()
        b.push(piece(0, .queen, .white), at: .origin)
        // Fill five of six sides, leave (0,1) open.
        let filled = [Hex(1, 0), Hex(1, -1), Hex(0, -1), Hex(-1, 0), Hex(-1, 1)]
        var id = 10
        for cell in filled { b.push(piece(id, .ant, .white), at: cell); id += 1 }
        // Give black a spider adjacent so it can slide into (0,1) — instead we
        // hand black an ant already touching the hive and let it move in.
        b.push(piece(50, .queen, .black), at: Hex(2, 0))
        b.push(piece(51, .ant, .black), at: Hex(2, -1))
        let state = GameState(board: b, current: .black,
                              unplaced: [], movesMade: [.white: 6, .black: 5])
        var rng = SeededRNG(seed: 7)
        let move = HiveAI.bestMove(for: state, difficulty: .hard, timeLimit: 5, rng: &rng)
        #expect(move != nil)
        let after = state.applying(move!)
        #expect(after.result == .win(.black))   // AI must find the mate in one
    }
}
