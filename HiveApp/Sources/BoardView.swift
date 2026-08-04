import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// The scrollable, zoomable board. Tiles are real views (so moves animate and
/// each tile is individually tappable); an auto-fit camera keeps the hive framed
/// until the player takes manual control by panning or zooming.
struct BoardView: View {
    let game: GameController
    var baseHexSize: CGFloat = 30
    /// Launches the guided tutorial overlay (owned by the root ContentView).
    var onStartTutorial: () -> Void = {}
    /// Press-and-hold on a tile asks the root to explain that piece's movement.
    var onInspectPiece: (Piece) -> Void = { _ in }

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var userAdjusted = false
    @State private var showRules = false
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private var layout: HexLayout { HexLayout(size: baseHexSize) }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                background
                    .contentShape(Rectangle())
                    .onTapGesture { game.deselect() }

                content(center: center)
                    .scaleEffect(zoom * pinch)
                    .offset(x: pan.width + drag.width, y: pan.height + drag.height)
                    .allowsHitTesting(!game.isThinking)
            }
            .clipped()
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
            // Docked at the mid-right edge — clear of the top status bar and the
            // hand trays along the bottom, which used to overlap these controls.
            .overlay(alignment: .trailing) { cameraControls }
            .onAppear { viewSize = geo.size; fit(animated: false) }
            .onChange(of: geo.size) { _, new in viewSize = new; if !userAdjusted { fit(animated: false) } }
            .onChange(of: game.state.board.tileCount) { _, _ in if !userAdjusted { fit(animated: true) } }
            .onChange(of: game.history.count) { _, new in if new == 0 { userAdjusted = false; fit(animated: true) } }
        }
        // Presented from the floating "book" button. Hosted here (not on the root
        // ContentView, which already owns the menu sheet) so the two never stack
        // — a second `.sheet` on one view triggers "only a single sheet is
        // supported". `RulesView` carries no NavigationStack of its own, so wrap
        // it in one to get the title bar and a Done button.
        .sheet(isPresented: $showRules) {
            NavigationStack {
                RulesView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showRules = false }.fontWeight(.semibold)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
    }

    // MARK: Content

    private func content(center: CGPoint) -> some View {
        ZStack {
            ForEach(renderedTiles) { rt in
                TileView(piece: rt.piece,
                         size: baseHexSize,
                         selected: game.isSelected(pieceID: rt.piece.id),
                         lastMoved: rt.lastMoved,
                         isBeetleTarget: rt.isBeetleTarget)
                    .position(rt.position + center)
                    .zIndex(rt.z)
                    .allowsHitTesting(rt.isTop)
                    .onTapGesture { game.tapHex(rt.hex) }
                    // Press-and-hold any tile on top of the hive to read what it
                    // does. Works whether or not it's the currently selected
                    // piece; the "Hold to see piece movement" hint teaches it.
                    .onLongPressGesture(minimumDuration: 0.4) { inspect(rt.piece) }
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
            ForEach(emptyTargets, id: \.self) { hex in
                TargetMarker(size: baseHexSize)
                    .position(layout.point(for: hex) + center)
                    .zIndex(500)
                    .onTapGesture { game.tapHex(hex) }
                    .transition(.opacity)
            }
        }
    }

    /// Fire a firm tactile tick and hand the held piece up to the root, which
    /// presents the movement-explanation modal.
    private func inspect(_ piece: Piece) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
        onInspectPiece(piece)
    }

    private var background: some View {
        LinearGradient(colors: [HiveTheme.bgTop, HiveTheme.bgBottom],
                       startPoint: .top, endPoint: .bottom)
            .overlay(
                RadialGradient(colors: [.white.opacity(0.05), .clear],
                               center: .center, startRadius: 0, endRadius: 420)
            )
            .ignoresSafeArea()
    }

    // MARK: Camera controls

    private var cameraControls: some View {
        VStack(spacing: 10) {
            cameraButton("graduationcap.fill") { onStartTutorial() }
            cameraButton("scope") { userAdjusted = false; fit(animated: true) }
            cameraButton("book.fill") { showRules = true }
        }
        .padding(12)
    }

    private func cameraButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($drag) { value, state, _ in state = value.translation }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
                userAdjusted = true
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                setZoom(zoom * value.magnification)
                userAdjusted = true
            }
    }

    private func setZoom(_ target: CGFloat) {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = min(max(target, 0.4), 3.0)
        }
    }

    // MARK: Auto-fit

    private func fit(animated: Bool) {
        let cells = game.state.board.occupiedCells
        guard !cells.isEmpty, viewSize != .zero else {
            withAnimation(animated ? .spring(response: 0.4, dampingFraction: 0.85) : nil) {
                pan = .zero; zoom = 1
            }
            return
        }
        let pts = cells.map { layout.point(for: $0) }
        let minX = pts.map(\.x).min()!, maxX = pts.map(\.x).max()!
        let minY = pts.map(\.y).min()!, maxY = pts.map(\.y).max()!
        let boundsW = (maxX - minX) + layout.tileWidth * 1.4
        let boundsH = (maxY - minY) + layout.tileHeight * 1.4
        let targetZoom = min(max(min(viewSize.width / boundsW, viewSize.height / boundsH), 0.5), 1.8)
        let bboxCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let newPan = CGSize(width: -bboxCenter.x * targetZoom, height: -bboxCenter.y * targetZoom)
        withAnimation(animated ? .spring(response: 0.45, dampingFraction: 0.85) : nil) {
            zoom = targetZoom
            pan = newPan
        }
    }

    // MARK: Rendered model

    private var lastMoveHex: Hex? {
        switch game.state.lastMove {
        case let .place(_, hex): return hex
        case let .move(_, _, to): return to
        default: return nil
        }
    }

    private var renderedTiles: [RenderedTile] {
        let board = game.state.board
        let targets = game.targets
        let lastHex = lastMoveHex
        var tiles: [RenderedTile] = []
        for hex in board.occupiedCells {
            let stack = board.stack(hex)
            for (level, piece) in stack.enumerated() {
                let isTop = level == stack.count - 1
                let base = layout.point(for: hex)
                let lift = CGPoint(x: CGFloat(level) * 3, y: CGFloat(level) * -4)
                let last = isTop && hex == lastHex
                tiles.append(RenderedTile(
                    piece: piece,
                    hex: hex,
                    position: base + lift,
                    isTop: isTop,
                    lastMoved: last,
                    isBeetleTarget: isTop && targets.contains(hex),
                    z: last ? 1000 : Double(level) + (isTop ? 100 : 0)
                ))
            }
        }
        return tiles
    }

    private var emptyTargets: [Hex] {
        game.targets.filter { !game.state.board.isOccupied($0) }
    }
}

private struct RenderedTile: Identifiable {
    let piece: Piece
    let hex: Hex
    let position: CGPoint
    let isTop: Bool
    let lastMoved: Bool
    let isBeetleTarget: Bool
    let z: Double
    var id: Int { piece.id }
}

/// Pulsing marker drawn on an empty cell that is a legal destination.
private struct TargetMarker: View {
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            RegularHexagon()
                .fill(HiveTheme.target.opacity(0.16))
            Circle()
                .fill(HiveTheme.target.opacity(0.9))
                .frame(width: size * 0.5, height: size * 0.5)
                .scaleEffect(pulse ? 1.15 : 0.85)
        }
        .frame(width: size * sqrt(3), height: size * 2)
        .contentShape(RegularHexagon())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
