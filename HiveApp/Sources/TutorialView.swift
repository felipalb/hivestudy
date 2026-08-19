import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Script model

/// One guided step. A step either just narrates (a "Next" button advances) or
/// asks for a single, constrained action — place a specific bug, or move a
/// specific piece — accepting only the highlighted cells. Each step optionally
/// loads its own drill position so the lessons stay isolated and reliable.
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

    /// The hand bug that should glow before it's picked up.
    var hintBug: Bug? { if case let .place(bug, _) = action { return bug }; return nil }
    /// The board piece that should glow before it's tapped.
    var hintPieceID: Int? { if case let .move(id, _, _) = action { return id }; return nil }
}

// MARK: - Controller

/// Drives the guided tutorial: a fixed script of drills, a displayed game state,
/// and constrained tap handling that only accepts the scripted action. Kept
/// entirely separate from `GameController` so the live game is never affected.
@MainActor
@Observable
final class TutorialController {
    enum Selection: Equatable { case none, hand(Bug), board(Int) }

    let steps: [TutorialStep]
    private(set) var index = 0
    private(set) var state: GameState
    private(set) var targets: Set<Hex> = []
    private(set) var selection: Selection = .none
    /// True between completing a step's action and auto-advancing — freezes input
    /// so a double-tap can't leak into the next step.
    private(set) var acted = false

    var step: TutorialStep { steps[index] }
    var stepNumber: Int { index + 1 }
    var stepCount: Int { steps.count }

    init() {
        let script = TutorialScript.build()
        steps = script
        state = script.first?.board ?? GameState()
        enter(0)
    }

    // MARK: Step flow

    private func enter(_ i: Int) {
        index = i
        if let board = step.board { state = board }
        selection = .none
        targets = []
        acted = false
    }

    /// Advance from a narration step (the "Next" button).
    func next() {
        guard case .narrate = step.action else { return }
        goForward()
    }

    private func goForward() {
        guard index + 1 < steps.count else { return }
        withAnimation(.easeInOut(duration: 0.25)) { enter(index + 1) }
    }

    // MARK: Constrained interaction

    func tapHand(_ bug: Bug) {
        guard !acted, case let .place(want, accept) = step.action, bug == want else { return }
        if selection == .hand(bug) {          // tap again to put it back down
            selection = .none; targets = []; return
        }
        selection = .hand(bug)
        targets = accept
        impact(.light)
    }

    func tapHex(_ hex: Hex) {
        guard !acted else { return }
        switch step.action {
        case .narrate:
            break

        case let .place(want, accept):
            guard selection == .hand(want) else { return }   // must pick the tile up first
            guard accept.contains(hex) else { return }        // ignore wrong cells
            perform(.place(want, at: hex))

        case let .move(pieceID, from, accept):
            if selection != .board(pieceID) {
                // First tap selects the scripted piece (any other tap is ignored).
                if state.board.topPiece(hex)?.id == pieceID {
                    selection = .board(pieceID)
                    targets = accept
                    impact(.light)
                }
                return
            }
            guard accept.contains(hex) else { return }
            perform(.move(pieceID: pieceID, from: from, to: hex))
        }
    }

    private func perform(_ move: Move) {
        acted = true
        selection = .none
        targets = []
        impact(.rigid)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            state.apply(move)
        }
        if state.result != .ongoing { notifyWin() }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            goForward()
        }
    }

    var isSelected: (Int) -> Bool { { [selection] id in selection == .board(id) } }

    // MARK: Haptics

    private func impact(_ style: Style) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style == .light ? .light : .rigid).impactOccurred()
        #endif
    }
    private func notifyWin() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    private enum Style { case light, rigid }
}

// MARK: - Script

/// Builds the drills and the ordered step list. Boards are constructed with
/// stable tile ids so the move steps can name their piece; the winning drill's
/// geometry is guarded by `TutorialScenarioTests` in the engine test suite.
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
                caption: "Bem-vindo ao Hive! Você vence cercando a Rainha adversária em todos os seis lados. Vamos aprender jogando alguns movimentos — toque em Próximo.",
                action: .narrate, board: drill1),

            TutorialStep(
                caption: "Coloque uma peça da sua mão. Novas peças devem tocar sua própria cor e nunca a do oponente. Toque no Gafanhoto brilhante, depois em um espaço brilhante.",
                action: .place(bug: .grasshopper, accept: placeCells1), board: drill1),

            TutorialStep(
                caption: "Sua Rainha deve estar no tabuleiro até o quarto turno — e nenhuma peça pode ser movida até que ela esteja em jogo.",
                action: .narrate, board: drill2),

            TutorialStep(
                caption: "É o quarto turno e sua Rainha ainda está na mão, então ela precisa ser colocada agora. Toque na Rainha brilhante, depois em um espaço brilhante.",
                action: .place(bug: .queen, accept: placeCells2), board: drill2),

            TutorialStep(
                caption: "Com sua Rainha em jogo, você pode mover peças. A Formiga Soldado desliza livremente ao redor da colmeia.",
                action: .narrate, board: drill3),

            TutorialStep(
                caption: "Mova sua Formiga. Toque nela para pegá-la, depois deslize até um espaço brilhante.",
                action: .move(pieceID: antID, from: Hex(-1, 0), accept: antTargets), board: drill3),

            // --- Per-bug movement drills ---
            TutorialStep(
                caption: "A Aranha move exatamente três espaços ao redor da colmeia — nem mais, nem menos. Leve a Aranha exatamente até o destino.",
                action: .narrate, board: drillSpider),

            TutorialStep(
                caption: "Mova sua Aranha: toque nela, depois toque em um espaço brilhante (exatamente 3 passos ao redor).",
                action: .move(pieceID: spiderDrillID, from: spiderDrillFrom, accept: spiderTargets), board: drillSpider),

            TutorialStep(
                caption: "O Besouro move apenas um espaço, mas pode subir no topo de outra peça, imobilizando-a. Suba seu Besouro em cima da peça adversária!",
                action: .narrate, board: drillBeetle),

            TutorialStep(
                caption: "Mova seu Besouro para cima da peça adversária.",
                action: .move(pieceID: beetleDrillID, from: beetleDrillFrom, accept: beetleTargets), board: drillBeetle),

            TutorialStep(
                caption: "A Joaninha move exatamente três espaços: sobe no topo da colmeia, cruza por cima de uma peça, depois desce para uma célula vazia. Leve-a para o outro lado!",
                action: .narrate, board: drillLadybug),

            TutorialStep(
                caption: "Mova sua Joaninha: ela vai subir, cruzar e descer. Toque nela, depois no destino brilhante.",
                action: .move(pieceID: ladybugDrillID, from: ladybugDrillFrom, accept: ladybugTargets), board: drillLadybug),

            TutorialStep(
                caption: "O Mosquito é especial: ele copia o movimento de qualquer inseto adjacente. Ao lado de uma Formiga, desliza como Formiga. Ao lado de um Gafanhoto, pula como Gafanhoto.",
                action: .narrate, board: drillMosquito),

            TutorialStep(
                caption: "Mova seu Mosquito: ele toca uma Formiga, então pode deslizar livremente. Leve-o ao destino.",
                action: .move(pieceID: mosquitoDrillID, from: mosquitoDrillFrom, accept: mosquitoTargets), board: drillMosquito),

            // --- Win drill ---
            TutorialStep(
                caption: "Agora o final. A Rainha das Pretas tem apenas um lado aberto. O Gafanhoto pula em linha reta sobre outras peças — direto para a abertura.",
                action: .narrate, board: drill4),

            TutorialStep(
                caption: "Pule seu Gafanhoto na abertura brilhante para cobrir o último lado da Rainha e vencer!",
                action: .move(pieceID: winnerID, from: Hex(2, 0), accept: [winCell]), board: drill4),

            TutorialStep(
                caption: "É assim que se joga — você cercou a Rainha e venceu! Coloque peças, proteja sua própria Rainha e feche todos os seis lados da adversária.",
                action: .narrate, board: nil, isFinal: true)
        ]
    }

    // Stable ids referenced by the move steps.
    static let antID = 2
    static let winnerID = 7
    // Per-bug drill IDs — each drill board assigns sequential IDs starting at 0.
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

    /// Two opposing tiles; White has a Grasshopper to place. Teaches adjacency.
    private static func placementDrill() -> GameState {
        let b = make([(Hex(0, 0), .spider, .white), (Hex(1, 0), .spider, .black)])
        return GameState(board: b, current: .white,
                         unplaced: [Piece(id: 200, bug: .grasshopper, color: .white)],
                         movesMade: [.white: 1, .black: 1])
    }

    /// White has taken three turns without a Queen — she is now forced.
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

    /// A tiny hive with White's Queen down and a White Ant free to slide (id 2).
    private static func moveDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),   // id 0
            (Hex(1, 0), .queen, .black),   // id 1
            (Hex(-1, 0), .ant, .white)     // id 2 — the ant that moves
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 2, .black: 2])
    }

    // MARK: - Per-Bug Drills

    /// Spider drill: White Spider (id 3) at (-2,1) must walk exactly 3 steps.
    /// Board: a small L-shaped hive so the spider has a clear 3-step route.
    ///   id 0: White Queen at (0,0)
    ///   id 1: Black Queen at (1,0)
    ///   id 2: Black Ant at (0,1)
    ///   id 3: White Spider at (-2,1) — the piece to move
    private static func spiderDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),    // id 0
            (Hex(1, 0), .queen, .black),    // id 1
            (Hex(0, 1), .ant, .black),      // id 2
            (Hex(-2, 1), .spider, .white),  // id 3 — spider to move
            (Hex(-1, 0), .ant, .white),     // id 4
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 3, .black: 2])
    }

    /// Beetle drill: White Beetle (id 2) at (-1,0) climbs onto Black's piece at (0,0).
    ///   id 0: White Queen at (0,-1)
    ///   id 1: Black Queen at (1,-1)
    ///   id 2: White Beetle at (-1,0) — the piece to move
    ///   id 3: Black Ant at (0,0) — target to climb on
    private static func beetleDrill() -> GameState {
        let b = make([
            (Hex(0, -1), .queen, .white),   // id 0
            (Hex(1, -1), .queen, .black),   // id 1
            (Hex(-1, 0), .beetle, .white),  // id 2 — beetle to move
            (Hex(0, 0), .ant, .black),      // id 3 — piece to climb onto
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 2, .black: 2])
    }

    /// Ladybug drill: White Ladybug (id 4) at (-2,1) does up-over-down across the hive.
    ///   id 0: White Queen at (0,0)
    ///   id 1: Black Queen at (1,0)
    ///   id 2: White Ant at (-1, 0)
    ///   id 3: Black Beetle at (0,1)
    ///   id 4: White Ladybug at (-2,1) — the piece to move
    private static func ladybugDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),     // id 0
            (Hex(1, 0), .queen, .black),     // id 1
            (Hex(-1, 0), .ant, .white),      // id 2
            (Hex(0, 1), .beetle, .black),    // id 3
            (Hex(-2, 1), .ladybug, .white),  // id 4 — ladybug to move
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 3, .black: 2])
    }

    /// Mosquito drill: White Mosquito (id 3) at (-1,1) touches a White Ant,
    /// so it can slide like an ant.
    ///   id 0: White Queen at (0,0)
    ///   id 1: Black Queen at (1,0)
    ///   id 2: White Ant at (0,1)
    ///   id 3: White Mosquito at (-1,1) — the piece to move
    private static func mosquitoDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .white),       // id 0
            (Hex(1, 0), .queen, .black),       // id 1
            (Hex(0, 1), .ant, .white),         // id 2
            (Hex(-1, 1), .mosquito, .white),   // id 3 — mosquito to move
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 3, .black: 1])
    }

    /// Black's Queen surrounded on five sides; White's Grasshopper (id 7) can
    /// jump into the last gap at (-1,0) to win. Verified by the engine tests.
    private static func winDrill() -> GameState {
        let b = make([
            (Hex(0, 0), .queen, .black),        // id 0
            (Hex(1, 0), .ant, .black),          // id 1  (E)
            (Hex(1, -1), .beetle, .white),      // id 2  (NE)
            (Hex(0, -1), .spider, .black),      // id 3  (NW)
            (Hex(-1, 1), .ant, .white),         // id 4  (SW)
            (Hex(0, 1), .grasshopper, .black),  // id 5  (SE)
            (Hex(1, 1), .queen, .white),        // id 6  — White Queen
            (Hex(2, 0), .grasshopper, .white)   // id 7  — the winning mover
        ])
        return GameState(board: b, current: .white,
                         unplaced: [], movesMade: [.white: 5, .black: 5])
    }
}

// MARK: - View

/// Full-screen guided tutorial overlay: a small board the player acts on under a
/// coach caption, with only the scripted move enabled at each step.
struct TutorialView: View {
    @State private var controller = TutorialController()
    let onExit: () -> Void
    let onPlayGame: () -> Void

    private var step: TutorialStep { controller.step }

    var body: some View {
        ZStack {
            LinearGradient(colors: [HiveTheme.bgTop, HiveTheme.bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                boardArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomPanel
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Label("Tutorial", systemImage: "graduationcap.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text("Passo \(controller.stepNumber) de \(controller.stepCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: Board

    private var boardArea: some View {
        GeometryReader { geo in
            let fit = fit(in: geo.size)
            let layout = HexLayout(size: fit.size)
            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2) - fit.center
            ZStack {
                ForEach(renderedTiles, id: \.piece.id) { rt in
                    TileView(piece: rt.piece, size: fit.size,
                             selected: controller.isSelected(rt.piece.id) || rt.hint)
                        .position(layout.point(for: rt.hex) + origin + rt.lift)
                        .zIndex(rt.z)
                        .allowsHitTesting(rt.isTop)
                        .onTapGesture { controller.tapHex(rt.hex) }
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                ForEach(Array(controller.targets), id: \.self) { hex in
                    if !controller.state.board.isOccupied(hex) {
                        TutorialTarget(size: fit.size)
                            .position(layout.point(for: hex) + origin)
                            .zIndex(600)
                            .onTapGesture { controller.tapHex(hex) }
                            .transition(.opacity)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: controller.index)
            .animation(.easeInOut(duration: 0.2), value: controller.targets)
        }
    }

    /// Fit the occupied + target cells into ~80% of the board area, choosing a
    /// hex size (tiles keep touching) and the centroid to centre on.
    private func fit(in area: CGSize) -> (size: CGFloat, center: CGPoint) {
        let cells = Set(controller.state.board.occupiedCells).union(controller.targets)
        guard !cells.isEmpty, area != .zero else { return (28, .zero) }
        let unit = HexLayout(size: 1)
        let pts = cells.map { unit.point(for: $0) }
        let minX = pts.map(\.x).min()!, maxX = pts.map(\.x).max()!
        let minY = pts.map(\.y).min()!, maxY = pts.map(\.y).max()!
        let boundsW = (maxX - minX) + sqrt(3.0)
        let boundsH = (maxY - minY) + 2
        let raw = min(area.width * 0.82 / boundsW, area.height * 0.82 / boundsH)
        let size = min(max(raw, 16), 34)
        return (size, CGPoint(x: (minX + maxX) / 2 * size, y: (minY + maxY) / 2 * size))
    }

    private var renderedTiles: [TutorialTile] {
        let board = controller.state.board
        let hintID = controller.step.hintPieceID
        var out: [TutorialTile] = []
        for hex in board.occupiedCells {
            let stack = board.stack(hex)
            for (level, piece) in stack.enumerated() {
                let isTop = level == stack.count - 1
                out.append(TutorialTile(
                    piece: piece, hex: hex,
                    lift: CGPoint(x: CGFloat(level) * 3, y: CGFloat(level) * -4),
                    isTop: isTop,
                    hint: isTop && piece.id == hintID && controller.selection == .none,
                    z: Double(level) + (isTop ? 100 : 0)))
            }
        }
        return out
    }

    // MARK: Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            if let bug = step.hintBug {
                handChip(bug)
            }
            coachBubble
            controls
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func handChip(_ bug: Bug) -> some View {
        VStack(spacing: 4) {
            TileView(piece: Piece(id: -1, bug: bug, color: .white), size: 30,
                     selected: controller.selection == .hand(bug))
                .frame(width: 30 * sqrt(3) + 6, height: 60)
                .scaleEffect(controller.selection == .hand(bug) ? 1.08 : 1)
                .overlay {
                    if controller.selection == .none {
                        RegularHexagon()
                            .stroke(HiveTheme.selection, lineWidth: 3)
                            .frame(width: 30 * sqrt(3), height: 60)
                            .modifier(Pulse())
                    }
                }
                .onTapGesture { controller.tapHand(bug) }
            Text(controller.selection == .hand(bug) ? "Agora toque em um espaço brilhante" : "Toque para pegar")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: controller.selection)
    }

    private var coachBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(HiveTheme.selection, in: Circle())
            Text(step.caption)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1))
        )
        .frame(maxWidth: 460)
    }

    @ViewBuilder private var controls: some View {
        if step.isFinal {
            VStack(spacing: 10) {
                bigButton("Jogar de Verdade", filled: true, action: onPlayGame)
                bigButton("Concluir", filled: false, action: onExit)
            }
            .frame(maxWidth: 460)
        } else if case .narrate = step.action {
            bigButton("Próximo", filled: true) { controller.next() }
                .frame(maxWidth: 460)
        }
        // Action steps have no button — completing the action advances.
    }

    private func bigButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(filled ? HiveTheme.selection : Color.white.opacity(0.10)))
                .foregroundStyle(filled ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}

private struct TutorialTile {
    let piece: Piece
    let hex: Hex
    let lift: CGPoint
    let isTop: Bool
    let hint: Bool
    let z: Double
}

/// Pulsing destination marker (a self-contained twin of BoardView's private one).
private struct TutorialTarget: View {
    let size: CGFloat
    @State private var pulse = false
    var body: some View {
        ZStack {
            RegularHexagon().fill(HiveTheme.target.opacity(0.16))
            Circle().fill(HiveTheme.target.opacity(0.9))
                .frame(width: size * 0.5, height: size * 0.5)
                .scaleEffect(pulse ? 1.15 : 0.85)
        }
        .frame(width: size * sqrt(3), height: size * 2)
        .contentShape(RegularHexagon())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// A gentle pulsing opacity, used on the "pick me up" hint ring.
private struct Pulse: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0.35)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
