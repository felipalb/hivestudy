import Testing
@testable import HiveEngine

@Suite struct CampaignTests {
    @Test func allSixCampaignLevelsAreConfigured() {
        #expect(CampaignLevel.allLevels.count == 6)
        for level in CampaignLevel.allLevels {
            let state = level.createInitialState()
            #expect(state.result == .ongoing)
            let moves = MoveGenerator.legalMoves(state)
            #expect(!moves.isEmpty)
        }
    }

    @Test func levelOneAntCanSlideAroundPerimeter() {
        let level1 = CampaignLevel.allLevels[0]
        let state = level1.createInitialState()
        let moves = MoveGenerator.legalMoves(state)

        // Find move where white ant slides to (-1, 1)
        let antMove = moves.first {
            if case let .move(_, from, to) = $0, state.board.topPiece(from)?.bug == .ant && to == Hex(-1, 1) { return true }
            return false
        }
        #expect(antMove != nil)

        if let antMove {
            let nextState = state.applying(antMove)
            #expect(nextState.queenSurroundCount(.black) == 5)
        }
    }

    @Test func levelTwoSpiderCanWinInOneTurn() {
        let level2 = CampaignLevel.allLevels[1]
        let state = level2.createInitialState()
        let moves = MoveGenerator.legalMoves(state)

        let spiderWinMove = moves.first {
            if case let .move(_, from, to) = $0, state.board.topPiece(from)?.bug == .spider && to == Hex(1, -1) { return true }
            return false
        }
        #expect(spiderWinMove != nil)

        if let spiderWinMove {
            let winState = state.applying(spiderWinMove)
            #expect(winState.result == GameResult.win(PlayerColor.white))
        }
    }

    @Test func levelThreeGrasshopperCanJumpToWin() {
        let level3 = CampaignLevel.allLevels[2]
        let state = level3.createInitialState()
        let moves = MoveGenerator.legalMoves(state)

        let grasshopperWinMove = moves.first {
            if case let .move(_, from, to) = $0, state.board.topPiece(from)?.bug == .grasshopper && to == Hex(1, 0) { return true }
            return false
        }
        #expect(grasshopperWinMove != nil)

        if let grasshopperWinMove {
            let winState = state.applying(grasshopperWinMove)
            #expect(winState.result == GameResult.win(PlayerColor.white))
        }
    }

    @Test func levelFourBeetleCanWin() {
        let level4 = CampaignLevel.allLevels[3]
        let state = level4.createInitialState()
        let moves = MoveGenerator.legalMoves(state)

        let beetleWin = moves.first {
            if case let .move(_, from, to) = $0, state.board.topPiece(from)?.bug == .beetle && to == Hex(0, 1) { return true }
            return false
        }
        #expect(beetleWin != nil)

        if let beetleWin {
            let winState = state.applying(beetleWin)
            #expect(winState.result == GameResult.win(PlayerColor.white))
        }
    }

    @Test func levelFiveLadybugCanDropToWin() {
        let level5 = CampaignLevel.allLevels[4]
        let state = level5.createInitialState()
        let moves = MoveGenerator.legalMoves(state)

        let ladybugWin = moves.first {
            if case let .move(_, from, to) = $0, state.board.topPiece(from)?.bug == .ladybug && to == Hex(0, 1) { return true }
            return false
        }
        #expect(ladybugWin != nil)

        if let ladybugWin {
            let winState = state.applying(ladybugWin)
            #expect(winState.result == GameResult.win(PlayerColor.white))
        }
    }

    @Test func didacticAISuggestsValidHints() {
        let level2 = CampaignLevel.allLevels[1]
        let state = level2.createInitialState()
        let hint = HiveAI.suggestHint(for: state)
        #expect(hint != nil)
        #expect(!hint!.explanation.isEmpty)
        #expect(hint!.targetHex == Hex(1, -1))
    }

    @Test func didacticAIPlaysGentleResponseInLevelOne() {
        let level1 = CampaignLevel.allLevels[0]
        var state = level1.createInitialState()
        // Find white ant at (2, -1)
        let moves = MoveGenerator.legalMoves(state)
        let firstAntMove = moves.first {
            if case let .move(_, from, to) = $0, from == Hex(2, -1) && to == Hex(-1, 1) { return true }
            return false
        }
        #expect(firstAntMove != nil)
        if let firstAntMove {
            state.apply(firstAntMove)
            #expect(state.current == PlayerColor.black)

            var rng = SystemRandomNumberGenerator()
            let aiMove = HiveAI.bestMove(for: state, difficulty: .didactic, timeLimit: 0.5, rng: &rng)
            #expect(aiMove != nil)
            if let aiMove {
                let nextState = state.applying(aiMove)
                #expect(nextState.result == GameResult.ongoing)
                let whiteMoves = MoveGenerator.legalMoves(nextState)
                let winningMove = whiteMoves.first { nextState.applying($0).result == GameResult.win(PlayerColor.white) }
                #expect(winningMove != nil)
            }
        }
    }
}
