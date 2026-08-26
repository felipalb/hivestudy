import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Script model

/// One guided adaptive step in the tutorial.
struct TutorialStep {
    enum Goal: Equatable {
        case narrate
        case place(bug: Bug)
        case move(bug: Bug)
        case winMatch
    }
    let caption: String
    let goal: Goal
    var isFinal = false

    /// The hand bug that should be placed in this step.
    var hintBug: Bug? { if case let .place(bug) = goal { return bug }; return nil }
    /// The bug that should move in this step.
    var hintMoveBug: Bug? { if case let .move(bug) = goal { return bug }; return nil }
}

// MARK: - Script

/// Builds the continuous evolving match and ordered step list.
private enum TutorialScript {
    static func build() -> [TutorialStep] {
        return [
            // 1. Placement Rule (Adaptive: any legal placement)
            TutorialStep(
                caption: "No Huli não há tabuleiro fixo — as próprias peças criam o campo em expansão. Novas peças devem tocar suas peças e nunca as do oponente. Toque ou arraste a Zebra da sua mão para qualquer espaço destacado.",
                goal: .place(bug: .spider)
            ),

            // 2. Queen Rule & Supreme Goal (Adaptive: any legal placement)
            TutorialStep(
                caption: "O objetivo supremo é cercar o Leão adversário em todos os 6 lados! Seu Leão deve entrar até o 4º turno para liberar a movimentação das suas peças. Coloque seu Leão em qualquer casa destacada!",
                goal: .place(bug: .queen)
            ),

            // 3. FUNDAMENTO PRINCIPAL: Regra da Colmeia Unida (100% Demonstrativo no tabuleiro real do jogador)
            TutorialStep(
                caption: "FUNDAMENTO DA COLMEIA UNIDA: A colmeia funciona como uma corrente contínua — ela NUNCA pode se partir em dois grupos! A peça com o pulsar vermelho suave sustenta a formação e NÃO PODE se mover. Apenas peças livres nas pontas têm permissão para se deslocar. Toque nas peças para testar ou clique em Entendi para prosseguir.",
                goal: .narrate
            ),

            // 4. Spider (Adaptive: any legal 3-step slide)
            TutorialStep(
                caption: "Com a colmeia protegida, sua Zebra na ponta está livre para se mover! A Zebra desliza pelo contorno dando sempre exatamente 3 passos — nem mais, nem menos. Mova sua Zebra pelo contorno!",
                goal: .move(bug: .spider)
            ),

            // 5. Beetle (Adaptive: climbing or moving)
            TutorialStep(
                caption: "O Gorila move 1 passo e tem um poder único: pode subir no topo de qualquer peça, imobilizando-a por completo. Mova seu Gorila para travar uma peça adversária ou avançar!",
                goal: .move(bug: .beetle)
            ),

            // 6. Grasshopper (Adaptive: straight line jump)
            TutorialStep(
                caption: "O Canguru não desliza pelo contorno: ele salta em linha reta sobre uma fileira de peças até o primeiro espaço livre. Salte com seu Canguru sobre a linha de peças!",
                goal: .move(bug: .grasshopper)
            ),

            // 7. Ladybug (Adaptive: fly 2 over, 1 down)
            TutorialStep(
                caption: "A Águia move 3 espaços: voa 2 casas pelo topo da formação e pousa em uma casa vazia. Voe com sua Águia por cima da colmeia!",
                goal: .move(bug: .ladybug)
            ),

            // 8. Mosquito (Adaptive: mimic adjacent bug)
            TutorialStep(
                caption: "O Camaleão copia o movimento de qualquer criatura que estiver tocando. Copie o poder da peça vizinha e mova seu Camaleão!",
                goal: .move(bug: .mosquito)
            ),

            // 9. Win / Checkmate (Adaptive: complete the surround)
            TutorialStep(
                caption: "O Leão adversário está cercado em 5 dos 6 lados nesta formação que você construiu! Faça o movimento decisivo para fechar o 6º lado e conquistar a vitória suprema!",
                goal: .winMatch
            ),

            // 10. Completion & Campaign CTA
            TutorialStep(
                caption: "Parabéns! Você dominou o princípio da Colmeia Unida e todas as criaturas do Huli em uma partida contínua e dinâmica. Inicie agora a Jornada da Colmeia para encarar desafios táticos progressivos!",
                goal: .narrate,
                isFinal: true
            )
        ]
    }
}

// MARK: - View

/// Full-screen interactive guided tutorial.
///
/// Uses the real `BoardView` and `GameController` animation pipeline:
/// - Reconstructs the exact step-by-step bug movement travel animations.
/// - Full drag-and-drop from hand and board with ghost tiles and target snapping.
/// - Press-and-hold on any piece opens `PieceMoveInfoOverlay` with animated diagrams.
/// - Real-time haptic feedback and coaches invalid taps with standard toast pills.
struct TutorialView: View {
    var canSkip: Bool = true
    let onExit: () -> Void
    let onPlayGame: () -> Void

    @State private var game = GameController(options: .tutorial)
    @State private var stepIndex = 0
    @State private var inspectedPiece: Piece?
    private let steps: [TutorialStep] = TutorialScript.build()

    private var currentStep: TutorialStep {
        steps[min(stepIndex, steps.count - 1)]
    }

    var body: some View {
        ZStack {
            // Full interactive game board
            BoardView(
                game: game,
                onInspectPiece: { inspectedPiece = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Toast pill feedback if player makes an invalid action
                if let toast = game.toast {
                    ToastPill(toast: toast)
                        .id(toast.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }

                // Bottom Panel: Hand Chip + Coach Bubble + Controls
                bottomPanel
            }

            // Hold-to-inspect piece overlay with animated movement diagram
            if let piece = inspectedPiece {
                PieceMoveInfoOverlay(piece: piece, onDismiss: { inspectedPiece = nil })
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: inspectedPiece)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.toast)
        .preferredColorScheme(.dark)
        .onAppear {
            loadStep(0)
        }
    }

    // MARK: - Step Management

    private func loadStep(_ idx: Int) {
        guard idx < steps.count else { return }
        stepIndex = idx
        let step = steps[idx]

        prepareBoardForStep(idx)

        let constraintKind = constraintForGoal(step.goal)
        game.setTutorialConstraint(constraintKind) {
            // Completed step action!
            Haptics.success()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.easeInOut(duration: 0.3)) {
                    if stepIndex + 1 < steps.count {
                        loadStep(stepIndex + 1)
                    }
                }
            }
        }
    }

    private func prepareBoardForStep(_ idx: Int) {
        if idx == 0 {
            // Initial opening state: White Ant at (0,0) and Black Ant at (1,0)
            var b = Board()
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 0))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            let unplaced = [
                Piece(id: 2, bug: .spider, color: .white),
                Piece(id: 4, bug: .queen, color: .white),
                Piece(id: 6, bug: .beetle, color: .white),
                Piece(id: 7, bug: .grasshopper, color: .white),
                Piece(id: 8, bug: .ladybug, color: .white),
                Piece(id: 9, bug: .mosquito, color: .white)
            ]
            let s = GameState(
                board: b,
                current: .white,
                unplaced: unplaced,
                movesMade: [.white: 1, .black: 1],
                config: GameConfig(tournamentOpening: false, expansions: [.ladybug, .mosquito])
            )
            game.loadTutorialState(s, constraint: .place(bug: .spider))
            return
        }

        // CONTINUOUS BOARD PRESERVATION:
        var currentBoard = game.state.board
        var unplaced = game.state.unplaced

        // Ensure that if Queen is on the board, it is removed from unplaced
        if game.state.queenPlaced(.white) || currentBoard.stacks.values.flatMap({ $0 }).contains(where: { $0.color == .white && $0.bug == .queen }) {
            unplaced.removeAll { $0.color == .white && $0.bug == .queen }
        }

        switch idx {
        case 1:
            // Step 2: Black places Queen strictly touching friendly pieces
            if !game.state.queenPlaced(.black) {
                if let spot = findPlacement(for: .black, in: currentBoard) {
                    currentBoard.push(Piece(id: 3, bug: .queen, color: .black), at: spot)
                }
            }
            if !unplaced.contains(where: { $0.bug == .queen && $0.color == .white }) && !game.state.queenPlaced(.white) && !currentBoard.stacks.values.flatMap({ $0 }).contains(where: { $0.color == .white && $0.bug == .queen }) {
                unplaced.append(Piece(id: 4, bug: .queen, color: .white))
            }

        case 2:
            // Step 3: Demonstrative One-Hive principle on player's live board
            break

        case 3:
            // Step 4: Spider movement - ensure Black piece is placed strictly touching the hive if added
            if !currentBoard.occupiedCells.contains(where: { currentBoard.topPiece($0)?.color == .black && currentBoard.topPiece($0)?.bug == .grasshopper }) {
                if let spot = findPlacement(for: .black, in: currentBoard) {
                    currentBoard.push(Piece(id: 5, bug: .grasshopper, color: .black), at: spot)
                }
            }

        case 4:
            // Step 5: Beetle climbing / pinning - ensure Beetle is touching the hive
            let hasBeetle = currentBoard.stacks.values.flatMap { $0 }.contains(where: { $0.bug == .beetle && $0.color == .white })
            if !hasBeetle {
                if let placement = findPlacement(for: .white, in: currentBoard) {
                    currentBoard.push(Piece(id: 6, bug: .beetle, color: .white), at: placement)
                } else if !unplaced.contains(where: { $0.bug == .beetle && $0.color == .white }) {
                    unplaced.append(Piece(id: 6, bug: .beetle, color: .white))
                }
            }

        case 5:
            // Step 6: Grasshopper jumping - ensure Grasshopper is touching the hive
            let hasGrasshopper = currentBoard.stacks.values.flatMap { $0 }.contains(where: { $0.bug == .grasshopper && $0.color == .white })
            if !hasGrasshopper {
                if let spot = findPlacement(for: .white, in: currentBoard) {
                    currentBoard.push(Piece(id: 7, bug: .grasshopper, color: .white), at: spot)
                } else if !unplaced.contains(where: { $0.bug == .grasshopper && $0.color == .white }) {
                    unplaced.append(Piece(id: 7, bug: .grasshopper, color: .white))
                }
            }

        case 6:
            // Step 7: Ladybug flying - ensure Ladybug is touching the hive
            let hasLadybug = currentBoard.stacks.values.flatMap { $0 }.contains(where: { $0.bug == .ladybug && $0.color == .white })
            if !hasLadybug {
                if let spot = findPlacement(for: .white, in: currentBoard) {
                    currentBoard.push(Piece(id: 8, bug: .ladybug, color: .white), at: spot)
                } else if !unplaced.contains(where: { $0.bug == .ladybug && $0.color == .white }) {
                    unplaced.append(Piece(id: 8, bug: .ladybug, color: .white))
                }
            }

        case 7:
            // Step 8: Mosquito mimicry - ensure Mosquito is touching the hive
            let hasMosquito = currentBoard.stacks.values.flatMap { $0 }.contains(where: { $0.bug == .mosquito && $0.color == .white })
            if !hasMosquito {
                if let spot = findPlacement(for: .white, in: currentBoard) {
                    currentBoard.push(Piece(id: 9, bug: .mosquito, color: .white), at: spot)
                } else if !unplaced.contains(where: { $0.bug == .mosquito && $0.color == .white }) {
                    unplaced.append(Piece(id: 9, bug: .mosquito, color: .white))
                }
            }

        case 8:
            // Step 9: Win / Checkmate
            // 1. Locate or guarantee Black Queen on the board, uncovered and clearly visible
            var blackQueenHex: Hex
            if let existingHex = currentBoard.location(of: 3) {
                blackQueenHex = existingHex
                // If anything was placed on top of the Queen (e.g. beetle), uncover it so Queen is visible
                while currentBoard.height(blackQueenHex) > 1 {
                    currentBoard.pop(at: blackQueenHex)
                }
            } else if let existingQueen = game.state.queenHex(.black) {
                blackQueenHex = existingQueen
                while currentBoard.height(blackQueenHex) > 1 {
                    currentBoard.pop(at: blackQueenHex)
                }
            } else if let spot = findPlacement(for: .black, in: currentBoard) {
                blackQueenHex = spot
                currentBoard.push(Piece(id: 3, bug: .queen, color: .black), at: spot)
            } else {
                blackQueenHex = currentBoard.occupiedCells.first?.neighbors.first(where: { !currentBoard.isOccupied($0) }) ?? Hex(2, 0)
                currentBoard.push(Piece(id: 3, bug: .queen, color: .black), at: blackQueenHex)
            }

            // 2. Ensure exactly 5 of the 6 neighbors of Black Queen are occupied, leaving 1 gap
            let neighbors = blackQueenHex.neighbors
            let emptyNeighbors = neighbors.filter { !currentBoard.isOccupied($0) }
            if emptyNeighbors.count > 1 {
                var dummyID = 20
                for (i, emptyHex) in emptyNeighbors.dropFirst().enumerated() {
                    currentBoard.push(Piece(id: dummyID + i, bug: .ant, color: .black), at: emptyHex)
                }
            }

            // 3. Ensure the player has an active White piece (Grasshopper, Ant, or Beetle) ready to move into the 1 open gap
            if let openGap = blackQueenHex.neighbors.first(where: { !currentBoard.isOccupied($0) }) {
                let testState = GameState(board: currentBoard, current: .white, unplaced: unplaced, movesMade: [.white: 5, .black: 5])
                let canReach = currentBoard.occupiedCells
                    .filter { currentBoard.topPiece($0)?.color == .white }
                    .flatMap { hex in currentBoard.topPiece(hex).map { MoveGenerator.destinations(for: $0.id, in: testState) } ?? [] }
                    .contains(openGap)

                if !canReach {
                    for d in 0..<6 {
                        let jumpOrigin = openGap.neighbor((d + 3) % 6).neighbor((d + 3) % 6)
                        if !currentBoard.isOccupied(jumpOrigin) && currentBoard.touchesHive(jumpOrigin) {
                            currentBoard.push(Piece(id: 7, bug: .grasshopper, color: .white), at: jumpOrigin)
                            break
                        }
                    }
                }
            }

        default:
            break
        }

        let updatedState = GameState(
            board: currentBoard,
            current: .white,
            unplaced: unplaced,
            movesMade: game.state.movesMade,
            lastMove: game.state.lastMove,
            config: game.state.config
        )

        // SMART REMEDIATION RULE:
        // SE apenas SE o usuário movimentou as peças de modo a bloquear ou impedir
        // a peça que será explicada nesta etapa, ajustamos as posições para permitir
        // a explicação e prática do movimento da criatura.
        if case let .move(wantBug) = steps[idx].goal {
            let canMove = hasLegalMoves(for: wantBug, in: updatedState)
            if !canMove {
                let remediated = remediationBoard(for: idx)
                game.loadTutorialState(remediated, constraint: constraintForGoal(steps[idx].goal))
                return
            }
        } else if case let .place(wantBug) = steps[idx].goal {
            let canPlace = !MoveGenerator.placementCells(updatedState).isEmpty
            if !canPlace {
                let remediated = remediationBoard(for: idx)
                game.loadTutorialState(remediated, constraint: constraintForGoal(steps[idx].goal))
                return
            }
        } else if case .winMatch = steps[idx].goal {
            let canWin = MoveGenerator.legalMoves(updatedState).contains { move in
                updatedState.applying(move).result == GameResult.win(PlayerColor.white)
            }
            if !canWin {
                let remediated = remediationBoard(for: idx)
                game.loadTutorialState(remediated, constraint: constraintForGoal(steps[idx].goal))
                return
            }
        }

        game.loadTutorialState(updatedState, constraint: constraintForGoal(steps[idx].goal))
    }

    private func hasLegalMoves(for bug: Bug, in state: GameState) -> Bool {
        let board = state.board
        let friendlyPieces = board.occupiedCells.compactMap { board.topPiece($0) }.filter { $0.color == .white && $0.bug == bug }
        for piece in friendlyPieces {
            let dests = MoveGenerator.destinations(for: piece.id, in: state)
            if !dests.isEmpty {
                return true
            }
        }
        return false
    }

    private func remediationBoard(for idx: Int) -> GameState {
        var b = Board()
        let unplaced: [Piece] = [
            Piece(id: 6, bug: .beetle, color: .white),
            Piece(id: 7, bug: .grasshopper, color: .white),
            Piece(id: 8, bug: .ladybug, color: .white),
            Piece(id: 9, bug: .mosquito, color: .white)
        ]

        switch idx {
        case 3:
            // Step 4: Spider remediation - free spider on outer corner
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 0))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            b.push(Piece(id: 4, bug: .queen, color: .white), at: Hex(0, -1))
            b.push(Piece(id: 3, bug: .queen, color: .black), at: Hex(1, 1))
            b.push(Piece(id: 2, bug: .spider, color: .white), at: Hex(-1, 0))
            return GameState(board: b, current: .white, unplaced: unplaced, movesMade: [.white: 3, .black: 3])

        case 4:
            // Step 5: Beetle remediation - beetle positioned to climb onto adjacent tile
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 0))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            b.push(Piece(id: 4, bug: .queen, color: .white), at: Hex(0, -1))
            b.push(Piece(id: 3, bug: .queen, color: .black), at: Hex(1, 1))
            b.push(Piece(id: 6, bug: .beetle, color: .white), at: Hex(-1, 0))
            return GameState(board: b, current: .white, unplaced: unplaced, movesMade: [.white: 3, .black: 3])

        case 5:
            // Step 6: Grasshopper remediation - line of pieces to jump over
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 0))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            b.push(Piece(id: 4, bug: .queen, color: .white), at: Hex(0, -1))
            b.push(Piece(id: 3, bug: .queen, color: .black), at: Hex(1, 1))
            b.push(Piece(id: 7, bug: .grasshopper, color: .white), at: Hex(-1, 0))
            return GameState(board: b, current: .white, unplaced: unplaced, movesMade: [.white: 3, .black: 3])

        case 6:
            // Step 7: Ladybug remediation - ladybug positioned to fly over hive
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 0))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            b.push(Piece(id: 4, bug: .queen, color: .white), at: Hex(0, -1))
            b.push(Piece(id: 3, bug: .queen, color: .black), at: Hex(1, 1))
            b.push(Piece(id: 8, bug: .ladybug, color: .white), at: Hex(-1, 0))
            return GameState(board: b, current: .white, unplaced: unplaced, movesMade: [.white: 3, .black: 3])

        case 7:
            // Step 8: Mosquito remediation - mosquito touching ant to copy
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 0))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            b.push(Piece(id: 4, bug: .queen, color: .white), at: Hex(0, -1))
            b.push(Piece(id: 3, bug: .queen, color: .black), at: Hex(1, 1))
            b.push(Piece(id: 9, bug: .mosquito, color: .white), at: Hex(-1, 0))
            return GameState(board: b, current: .white, unplaced: unplaced, movesMade: [.white: 3, .black: 3])

        case 8:
            // Step 9: Win remediation - Black queen surrounded on 5 sides, grasshopper jumps into 6th
            b.push(Piece(id: 3, bug: .queen, color: .black), at: Hex(0, 0))
            b.push(Piece(id: 0, bug: .ant, color: .white), at: Hex(0, 1))
            b.push(Piece(id: 1, bug: .ant, color: .black), at: Hex(1, 0))
            b.push(Piece(id: 4, bug: .queen, color: .white), at: Hex(1, -1))
            b.push(Piece(id: 2, bug: .spider, color: .white), at: Hex(0, -1))
            b.push(Piece(id: 6, bug: .beetle, color: .white), at: Hex(-1, 0))
            b.push(Piece(id: 7, bug: .grasshopper, color: .white), at: Hex(-3, 2))
            return GameState(board: b, current: .white, unplaced: [], movesMade: [.white: 6, .black: 6])

        default:
            return game.state
        }
    }

    /// Strictly finds a legal placement cell touching the hive according to official Hive rules.
    private func findPlacement(for color: PlayerColor, in board: Board) -> Hex? {
        let tempState = GameState(
            board: board,
            current: color,
            unplaced: [Piece(id: 999, bug: .ant, color: color)],
            movesMade: [.white: 2, .black: 2]
        )
        let legalCells = MoveGenerator.placementCells(tempState)
        if let first = legalCells.first { return first }

        // Fallback: any empty neighbor of a friendly piece that strictly touches the hive
        let friendlyCells = board.occupiedCells.filter { board.topPiece($0)?.color == color }
        for cell in friendlyCells {
            for neighbor in board.emptyNeighbors(cell) {
                if board.touchesHive(neighbor) {
                    return neighbor
                }
            }
        }
        for cell in board.occupiedCells {
            for neighbor in board.emptyNeighbors(cell) {
                if board.touchesHive(neighbor) {
                    return neighbor
                }
            }
        }
        return nil
    }

    private func constraintForGoal(_ goal: TutorialStep.Goal) -> GameController.TutorialConstraint.Kind {
        switch goal {
        case .narrate: return .none
        case let .place(bug): return .place(bug: bug)
        case let .move(bug): return .move(bug: bug)
        case .winMatch: return .winMatch
        }
    }

    private func advanceNarration() {
        guard case .narrate = currentStep.goal, stepIndex + 1 < steps.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            loadStep(stepIndex + 1)
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Hand Chip if placing a piece
            if let bug = currentStep.hintBug {
                handPieceChip(bug)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Coach narrative card
            coachCard

            // Action buttons
            controls
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Hand Piece Chip with Tap + Drag + Hold

    private func handPieceChip(_ bug: Bug) -> some View {
        let isSelected = game.selection == .hand(bug, .white)
        let isDragging = isDraggingBug(bug)

        return VStack(spacing: 4) {
            ZStack {
                TileView(
                    piece: Piece(id: -1, bug: bug, color: .white),
                    size: 34,
                    selected: isSelected
                )
                .frame(width: 60, height: 68)
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .opacity(isDragging ? 0.3 : 1.0)
                .overlay {
                    if game.selection == .none && !game.dragState.isDragging {
                        RegularHexagon()
                            .stroke(HiveTheme.selection, lineWidth: 3)
                            .frame(width: 34 * sqrt(3), height: 68)
                            .modifier(PulseModifier())
                    }
                }
            }
            .onTapGesture(count: 2) {
                Haptics.selection()
                inspectedPiece = Piece(id: -1, bug: bug, color: .white)
            }
            .onTapGesture(count: 1) {
                game.selectHand(bug, .white)
            }
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        if !game.dragState.isDragging {
                            game.beginDrag(.hand(bug, .white))
                        }
                        game.dragState.fingerPosition = value.location
                    }
                    .onEnded { _ in
                        guard game.dragState.isDragging else { return }
                        if let hex = game.dragState.hoveredHex,
                           game.dragState.validTargets.contains(hex) {
                            game.commitDrag(to: hex)
                        } else {
                            game.cancelDrag()
                        }
                    }
            )

            Text(isSelected ? "Arraste ou toque em um espaço destacado" : "Toque ou arraste para colocar")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private func isDraggingBug(_ bug: Bug) -> Bool {
        if case let .hand(b, _) = game.dragState.source, b == bug { return true }
        return false
    }

    // MARK: - Coach Narrative Card

    private var coachCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(HiveTheme.selection, in: Circle())

            Text(currentStep.caption)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
        )
        .frame(maxWidth: 480)
    }

    // MARK: - Controls

    @ViewBuilder private var controls: some View {
        if currentStep.isFinal {
            VStack(spacing: 10) {
                bigButton("Iniciar Jornada da Colmeia", filled: true, action: onPlayGame)
                if canSkip {
                    bigButton("Voltar ao Início", filled: false, action: onExit)
                }
            }
            .frame(maxWidth: 480)
        } else if case .narrate = currentStep.goal {
            VStack(spacing: 8) {
                bigButton(stepIndex == 2 ? "Entendi o Princípio, Continuar" : "Próximo", filled: true) { advanceNarration() }
                if canSkip {
                    Button("Pular Tutorial", action: onExit)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: 480)
        } else {
            if canSkip {
                Button("Pular Tutorial", action: onExit)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 2)
            }
        }
    }

    private func bigButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(filled ? HiveTheme.selection : Color.white.opacity(0.10))
                )
                .foregroundStyle(filled ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast Pill View helper for tutorial

private struct ToastPill: View {
    let toast: GameController.Toast

    var body: some View {
        HStack(spacing: 7) {
            if let icon = toast.icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HiveTheme.selection)
            }
            Text(toast.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 0.95)
            .opacity(isPulsing ? 1.0 : 0.7)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
