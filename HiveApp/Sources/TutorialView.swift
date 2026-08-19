import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Script model

/// One guided step in the tutorial.
struct TutorialStep {
    enum Action: Equatable {
        case narrate
        case place(bug: Bug, accept: Set<Hex>)
        case move(pieceID: Int, from: Hex, accept: Set<Hex>)
    }
    let caption: String
    let action: Action
    /// When non-nil, this position is loaded on entering the step.
    let board: GameState?
    /// The last step shows "finish" buttons instead of "Next".
    var isFinal = false

    /// The hand bug that should be placed in this step.
    var hintBug: Bug? { if case let .place(bug, _) = action { return bug }; return nil }
    /// The board piece that should move in this step.
    var hintPieceID: Int? { if case let .move(id, _, _) = action { return id }; return nil }
}

// MARK: - Script

/// Builds the drills and the ordered step list.
private enum TutorialScript {
    static func build() -> [TutorialStep] {
        let drill1 = placementDrill()
        let drill2 = queenDrill()
        let drill3 = moveDrill()
        let drillSpider = spiderDrill()
        let drillBeetle = beetleDrill()
        let drillLadybug = ladybugDrill()
        let drillMosquito = mosquitoDrill()
        let drill4 = winDrill()

        let placeCells1 = Set(MoveGenerator.placementCells(drill1))
        let placeCells2 = Set(MoveGenerator.placementCells(drill2))
        let antTargets = Set(MoveGenerator.destinations(for: antID, in: drill3))
        let spiderTargets = Set(MoveGenerator.destinations(for: spiderDrillID, in: drillSpider))
        let beetleTargets = Set(MoveGenerator.destinations(for: beetleDrillID, in: drillBeetle))
        let ladybugTargets = Set(MoveGenerator.destinations(for: ladybugDrillID, in: drillLadybug))
        let mosquitoTargets = Set(MoveGenerator.destinations(for: mosquitoDrillID, in: drillMosquito))
        let winCell = Hex(-1, 0)

        return [
            // --- Core tutorial ---
            TutorialStep(
                caption: "Bem-vindo ao Hive! Você vence cercando a Rainha adversária em todos os seis lados. Vamos aprender jogando — toque em Próximo.",
                action: .narrate, board: drill1),

            TutorialStep(
                caption: "Coloque uma peça da sua mão. Novas peças devem tocar sua própria cor e nunca a do oponente. Toque ou arraste o Gafanhoto até um espaço destacado.",
                action: .place(bug: .grasshopper, accept: placeCells1), board: drill1),

            TutorialStep(
                caption: "Sua Rainha deve estar no tabuleiro até o quarto turno — e nenhuma peça pode ser movida até que ela esteja em jogo.",
                action: .narrate, board: drill2),

            TutorialStep(
                caption: "É o quarto turno e sua Rainha ainda está na mão. Ela precisa entrar agora! Toque ou arraste sua Rainha até um espaço destacado.",
                action: .place(bug: .queen, accept: placeCells2), board: drill2),

            TutorialStep(
                caption: "Com sua Rainha em jogo, você pode mover peças. A Formiga Soldado desliza livremente por qualquer distância ao redor da colmeia.",
                action: .narrate, board: drill3),

            TutorialStep(
                caption: "Mova sua Formiga: toque nela ou arraste-a diretamente para um dos espaços destacados ao redor da colmeia.",
                action: .move(pieceID: antID, from: Hex(-1, 0), accept: antTargets), board: drill3),

            // --- Per-bug movement drills ---
            TutorialStep(
                caption: "A Aranha move exatamente três espaços ao redor da colmeia — nem mais, nem menos. Segure qualquer peça para ver suas regras de movimento.",
                action: .narrate, board: drillSpider),

            TutorialStep(
                caption: "Mova sua Aranha: toque ou arraste-a até o destino (exatamente 3 passos ao redor da colmeia).",
                action: .move(pieceID: spiderDrillID, from: spiderDrillFrom, accept: spiderTargets), board: drillSpider),

            TutorialStep(
                caption: "O Besouro move apenas um espaço, mas pode subir no topo de outra peça, imobilizando-a. Suba seu Besouro em cima da peça adversária!",
                action: .narrate, board: drillBeetle),

            TutorialStep(
                caption: "Mova seu Besouro para cima da peça adversária (você pode tocar ou arrastar).",
                action: .move(pieceID: beetleDrillID, from: beetleDrillFrom, accept: beetleTargets), board: drillBeetle),

            TutorialStep(
                caption: "A Joaninha move exatamente três espaços: sobe dois pelo topo da colmeia e desce em uma célula vazia. Experimente!",
                action: .narrate, board: drillLadybug),

            TutorialStep(
                caption: "Mova sua Joaninha: ela vai subir, cruzar e descer. Toque ou arraste-a até o destino.",
                action: .move(pieceID: ladybugDrillID, from: ladybugDrillFrom, accept: ladybugTargets), board: drillLadybug),

            TutorialStep(
                caption: "O Mosquito copia o movimento de qualquer inseto adjacente. Ao lado de uma Formiga, desliza como Formiga. Ao lado de um Gafanhoto, pula como Gafanhoto.",
                action: .narrate, board: drillMosquito),

            TutorialStep(
                caption: "Mova seu Mosquito: ele toca uma Formiga, então pode deslizar livremente pelo perímetro da colmeia.",
                action: .move(pieceID: mosquitoDrillID, from: mosquitoDrillFrom, accept: mosquitoTargets), board: drillMosquito),

            // --- Win drill ---
            TutorialStep(
                caption: "Agora o xeque-mate! A Rainha adversária tem apenas um lado aberto. O Gafanhoto pula em linha reta sobre as peças até a primeira vaga.",
                action: .narrate, board: drill4),

            TutorialStep(
                caption: "Pule seu Gafanhoto na abertura destacada para fechar o último lado da Rainha e vencer a partida!",
                action: .move(pieceID: winnerID, from: Hex(2, 0), accept: [winCell]), board: drill4),

            TutorialStep(
                caption: "Parabéns! Você cercou a Rainha adversária e dominou todas as regras fundamentais do Hive.",
                action: .narrate, board: nil, isFinal: true)
        ]
    }

    // Stable ids referenced by the move steps.
    static let antID = 2
    static let winnerID = 7
    static let spiderDrillID = 3
    static let spiderDrillFrom = Hex(-2, 1)
    static let beetleDrillID = 2
    static let beetleDrillFrom = Hex(-1, 0)
    static let ladybugDrillID = 4
    static let ladybugDrillFrom = Hex(-2, 1)
    static let mosquitoDrillID = 3
    static let mosquitoDrillFrom = Hex(-1, 1)

    private static func make(_ tiles: [(Hex, Bug, PlayerColor)]) -> Board {
        var b = Board()
        var id = 0
        for (hex, bug, color) in tiles { b.push(Piece(id: id, bug: bug, color: color), at: hex); id += 1 }
        return b
    }

    private static func placementDrill() -> GameState {
        let b = make([(Hex(0, 0), .spider, .white), (Hex(1, 0), .spider, .black)])
        return GameState(board: b, current: .white,
                         unplaced: [Piece(id: 200, bug: .grasshopper, color: .white)],
                         movesMade: [.white: 1, .black: 1])
    }

    private static func queenDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .ant, .white),   (Hex(1, 0), .ant, .black),
            (Hex(-1, 0), .spider, .white), (Hex(2, 0), .ant, .black),
            (Hex(-2, 0), .beetle, .white), (Hex(3, 0), .spider, .black)
        ])
        return GameState(board: b, current: .white,
                         unplaced: [Piece(id: 200, bug: .queen, color: .white)],
                         movesMade: [.white: 3, .black: 3])
    }

    private static func moveDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .queen, .black),
            (Hex(-1, 0), .ant, .white)
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 2, .black: 2])
    }

    private static func spiderDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .queen, .black),
            (Hex(0, 1), .ant, .black),
            (Hex(-2, 1), .spider, .white),
            (Hex(-1, 0), .ant, .white),
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 3, .black: 2])
    }

    private static func beetleDrill() -> GameState {
        let b = make([
            (Hex(0, -1), .queen, .white),
            (Hex(1, -1), .queen, .black),
            (Hex(-1, 0), .beetle, .white),
            (Hex(0, 0), .ant, .black),
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 2, .black: 2])
    }

    private static func ladybugDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .queen, .black),
            (Hex(-1, 0), .ant, .white),
            (Hex(0, 1), .beetle, .black),
            (Hex(-2, 1), .ladybug, .white),
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 3, .black: 2])
    }

    private static func mosquitoDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),
            (Hex(1, 0), .queen, .black),
            (Hex(0, 1), .ant, .white),
            (Hex(-1, 1), .mosquito, .white),
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 3, .black: 1])
    }

    private static func winDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .black),
            (Hex(1, 0), .ant, .black),
            (Hex(1, -1), .beetle, .white),
            (Hex(0, -1), .spider, .black),
            (Hex(-1, 1), .ant, .white),
            (Hex(0, 1), .grasshopper, .black),
            (Hex(1, 1), .queen, .white),
            (Hex(2, 0), .grasshopper, .white)
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 5, .black: 5])
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
                // Tutorial Header
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

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

        let constraintKind: GameController.TutorialConstraint.Kind
        switch step.action {
        case .narrate:
            constraintKind = .none
        case let .place(bug, accept):
            constraintKind = .place(bug: bug, targets: accept)
        case let .move(pieceID, _, accept):
            constraintKind = .move(pieceID: pieceID, targets: accept)
        }

        let targetBoard = step.board ?? game.state
        game.loadTutorialState(targetBoard, constraint: constraintKind) {
            // Completed step action!
            Haptics.success()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 0.3)) {
                    if stepIndex + 1 < steps.count {
                        loadStep(stepIndex + 1)
                    }
                }
            }
        }
    }

    private func advanceNarration() {
        guard case .narrate = currentStep.action, stepIndex + 1 < steps.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            loadStep(stepIndex + 1)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(HiveTheme.selection)
                Text("Tutorial")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Spacer()

            Text("Passo \(stepIndex + 1) de \(steps.count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))

            Spacer()

            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(HiveTheme.danger)
                    .overlay(Circle().stroke(HiveTheme.danger.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sair do tutorial")
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
            .onTapGesture {
                game.selectHand(bug, .white)
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                Haptics.selection()
                inspectedPiece = Piece(id: -1, bug: bug, color: .white)
            }
            .gesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
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
                bigButton("Jogar de Verdade", filled: true, action: onPlayGame)
                bigButton("Voltar ao Início", filled: false, action: onExit)
            }
            .frame(maxWidth: 480)
        } else if case .narrate = currentStep.action {
            bigButton("Próximo", filled: true) { advanceNarration() }
                .frame(maxWidth: 480)
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
