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
    /// Press-and-hold on a tile asks the root to explain that piece's movement.
    var onInspectPiece: (Piece) -> Void = { _ in }

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var userAdjusted = false
    /// Stashed center of the GeometryReader — used to convert global finger
    /// coordinates into board-local hex coordinates during a drag.
    @State private var boardCenter: CGPoint = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                // Ghost tile that follows the finger during a drag
                dragGhostOverlay(center: center, geoSize: geo.size)

                // Drag target markers (shown during drag, above the board content)
                if game.dragState.isDragging {
                    dragTargetsOverlay(center: center)
                        .scaleEffect(zoom * pinch)
                        .offset(x: pan.width + drag.width, y: pan.height + drag.height)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .coordinateSpace(name: "board")
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .onAppear { viewSize = geo.size; boardCenter = center; fit(animated: false) }
            .onChange(of: geo.size) { _, new in
                viewSize = new
                boardCenter = CGPoint(x: new.width / 2, y: new.height / 2)
                if !userAdjusted { fit(animated: false) }
            }
            .onChange(of: game.state.board.tileCount) { _, _ in if !userAdjusted { fit(animated: true) } }
            .onChange(of: game.history.count) { _, new in if new == 0 { userAdjusted = false; fit(animated: true) } }
            .onChange(of: game.recenterTrigger) { _, _ in userAdjusted = false; fit(animated: true) }
            // Keep hoveredHex in sync with the finger during hand-originated
            // drags (board-originated drags update it in their own gesture).
            .onChange(of: game.dragState.fingerPosition) { _, pos in
                guard game.dragState.isDragging else { return }
                if case .hand = game.dragState.source {
                    let hex = globalToBoardHex(pos)
                    game.dragState.hoveredHex = game.dragState.validTargets.contains(hex) ? hex : nil
                }
            }
        }
    }

    // MARK: Content

    private func content(center: CGPoint) -> some View {
        ZStack {
            ForEach(renderedTiles) { rt in
                if !isHiddenByAnimation(rt) {
                    TileView(piece: rt.piece,
                             size: baseHexSize,
                             selected: game.isSelected(pieceID: rt.piece.id),
                             lastMoved: rt.lastMoved,
                             isBeetleTarget: rt.isBeetleTarget,
                             rejectedSeq: rejectedSeq(for: rt))
                        .position(rt.position + center)
                        .zIndex(rt.z)
                        .opacity(isDragSource(rt) ? 0.3 : 1)
                        .allowsHitTesting(rt.isTop)
                        .onTapGesture { game.tapHex(rt.hex) }
                        .onLongPressGesture(minimumDuration: 0.4) { inspect(rt.piece) }
                        .gesture(tileDragGesture(rt))
                        .transition(tileTransition)
                        .accessibilityLabel(accessibilityLabel(for: rt))
                        .accessibilityAddTraits(rt.isTop ? .isButton : [])
                }
            }

            // Queen danger rings
            if game.state.result == .ongoing {
                ForEach([PlayerColor.white, .black], id: \.self) { color in
                    if let queenHex = queenHex(for: color) {
                        QueenDangerRing(
                            coveredSides: coveredSides(of: queenHex, color: color),
                            color: color,
                            size: baseHexSize
                        )
                        .position(layout.point(for: queenHex) + center)
                        .zIndex(999)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
            }

            // Selected piece aura
            if case let .board(id, hex) = game.selection,
               let piece = game.state.board.topPiece(hex), piece.id == id {
                SelectedAura(color: piece.color, size: baseHexSize)
                    .position(layout.point(for: hex) + center)
                    .zIndex(998)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            ForEach(emptyTargets, id: \.self) { hex in
                TargetMarker(size: baseHexSize)
                    .position(layout.point(for: hex) + center)
                    .zIndex(500)
                    .onTapGesture { game.tapHex(hex) }
                    .transition(.opacity)
                    .accessibilityLabel("Casa livre disponível")
                    .accessibilityAddTraits(.isButton)
            }

            // Hint highlights: a glowing marker on the suggested destination
            // (tap it to play the suggestion) and a ring on the source piece.
            if game.state.result == .ongoing {
                if let to = game.hintToHex {
                    HintMarker(size: baseHexSize)
                        .position(layout.point(for: to) + center)
                        .zIndex(600)
                        .onTapGesture { game.playHint() }
                        .transition(.opacity)
                        .accessibilityLabel("Dica: jogar aqui")
                        .accessibilityAddTraits(.isButton)
                }
                if let from = game.hintFromHex {
                    HintSourceRing(size: baseHexSize)
                        .position(layout.point(for: from) + center)
                        .zIndex(599)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }

            // Animation overlay
            animationOverlay(center: center)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Animation Overlay

    @ViewBuilder
    private func animationOverlay(center: CGPoint) -> some View {
        switch game.animationPhase {
        case .none:
            EmptyView()

        case .drop(let piece, let hex):
            let pos = layout.point(for: hex) + center
            ZStack {
                // Shockwave ring
                Circle()
                    .stroke(HiveTheme.tileBorder(piece.color).opacity(0.6), lineWidth: 2)
                    .frame(width: baseHexSize * 1.5, height: baseHexSize * 1.5)
                    .scaleEffect(0.3 + game.animationProgress * 1.5)
                    .opacity(Double(1.0 - game.animationProgress) * 0.8)
                    .position(pos)

                // Dropping piece
                TileView(piece: piece, size: baseHexSize, selected: false,
                         lastMoved: false, isBeetleTarget: false)
                    .scaleEffect(dropScale(game.animationProgress))
                    .opacity(Double(min(1, game.animationProgress * 2.5)))
                    .position(pos)
                    .zIndex(2000)
            }

        case .travel(let piece, let path):
            travelOverlay(piece: piece, path: path, center: center)
        }
    }

    /// Renders a piece travelling its reconstructed route. The tile visibly
    /// *steps* through each intermediate hex (eased per segment), so the
    /// animation demonstrates the bug's movement rule rather than teleporting:
    /// sliders stop on every hex of their walk, the grasshopper arcs over a
    /// pulsing line of overflown tiles, the beetle grows/shrinks with stack
    /// level, and the ladybug climbs onto the roof, crosses it, then drops.
    @ViewBuilder
    private func travelOverlay(piece: Piece, path: MovePath, center: CGPoint) -> some View {
        let t = game.animationProgress
        let points = path.steps.map { layout.point(for: $0.hex) + lift(for: $0.level) + center }
        let groundPoints = path.steps.map { layout.point(for: $0.hex) + center }

        switch path.kind {
        case .slide:
            TileView(piece: piece, size: baseHexSize, selected: false,
                     lastMoved: false, isBeetleTarget: false)
                .position(polylinePosition(points: points, progress: t))
                .zIndex(2000)

        case .jump:
            // Pulse every overflown tile while the hop is in flight — makes it
            // legible *what* the grasshopper jumped over.
            ForEach(Array(path.steps.enumerated()), id: \.offset) { index, step in
                if index > 0 && index < path.steps.count - 1 {
                    RegularHexagon()
                        .fill(HiveTheme.accent(.grasshopper).opacity(0.32 * jumpGlow(t)))
                        .frame(width: baseHexSize * sqrt(3), height: baseHexSize * 2)
                        .position(layout.point(for: step.hex) + center)
                        .zIndex(1999)
                }
            }
            let hopHeight = min(96, 44 + CGFloat(path.steps.count - 2) * 9)
            TileView(piece: piece, size: baseHexSize, selected: false,
                     lastMoved: false, isBeetleTarget: false)
                .scaleEffect(1.0 + arcScale(t) * 0.15)
                .position(arcPosition(from: points.first ?? center, to: points.last ?? center,
                                      progress: t, height: hopHeight))
                .zIndex(2000)

        case .climb:
            let eased = easeInOut(t)
            let fromLevel = CGFloat(path.steps.first?.level ?? 0)
            let toLevel = CGFloat(path.steps.last?.level ?? 0)
            let level = fromLevel + (toLevel - fromLevel) * eased
            let base = lerp(points.first ?? center, points.last ?? center, eased)
            let arcHeight: CGFloat = toLevel > fromLevel ? 26 : (toLevel < fromLevel ? 18 : 8)
            TileView(piece: piece, size: baseHexSize, selected: false,
                     lastMoved: false, isBeetleTarget: false)
                .scaleEffect(1.0 + level * 0.10)
                .position(CGPoint(x: base.x, y: base.y - sin(eased * .pi) * arcHeight))
                .zIndex(2000)

        case .overTheTop:
            let pos = polylinePosition(points: points, progress: t)
            let groundPos = polylinePosition(points: groundPoints, progress: t)
            let level = levelAlong(path: path, progress: t)
            // A soft ground shadow that grows with altitude sells "up on the
            // roof" vs "down on the table" without a word of text.
            Ellipse()
                .fill(.black.opacity(0.10 + 0.09 * min(level, 3)))
                .frame(width: baseHexSize * (1.15 + 0.20 * min(level, 3)),
                       height: baseHexSize * (0.40 + 0.06 * min(level, 3)))
                .position(x: groundPos.x, y: groundPos.y + baseHexSize * 0.74)
                .blur(radius: 2)
                .zIndex(1998)
            // A small pop as the tile drops off the roof on the final segment.
            let landing = t > 0.66 ? sin(min(1, (t - 0.66) / 0.34) * .pi) * 0.08 : 0
            TileView(piece: piece, size: baseHexSize, selected: false,
                     lastMoved: false, isBeetleTarget: false)
                .scaleEffect(1.0 + 0.09 * min(level, 3) + landing)
                .position(pos)
                .zIndex(2000)
        }
    }

    // MARK: - Animation Math

    private func dropScale(_ t: CGFloat) -> CGFloat {
        // Bounce ease-out: starts large, overshoots slightly, settles
        let bounce = 1.0 - pow(1.0 - t, 3)
        let overshoot = sin(t * .pi) * 0.12
        return 1.3 - bounce * 0.3 + overshoot
    }

    /// Position along a multi-stop route at `progress` ∈ [0,1]. Each segment
    /// gets an equal time slice and eases individually, so the tile visibly
    /// *steps* hex to hex instead of gliding one smooth line.
    private func polylinePosition(points: [CGPoint], progress: CGFloat) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let segments = CGFloat(points.count - 1)
        let scaled = min(progress, 0.9999) * segments
        let index = Int(scaled)
        let local = easeInOut(scaled - CGFloat(index))
        return lerp(points[index], points[index + 1], local)
    }

    /// Interpolated stack level along a route at `progress` — drives the
    /// beetle/ladybug altitude scaling and ground shadow.
    private func levelAlong(path: MovePath, progress: CGFloat) -> CGFloat {
        let segments = CGFloat(path.steps.count - 1)
        guard segments > 0 else { return 0 }
        let scaled = min(progress, 0.9999) * segments
        let index = Int(scaled)
        let local = scaled - CGFloat(index)
        let a = CGFloat(path.steps[index].level)
        let b = CGFloat(path.steps[index + 1].level)
        return a + (b - a) * local
    }

    /// The same per-level offset stacked tiles render with, so a travelling
    /// beetle lines up with the stack it is climbing onto.
    private func lift(for level: Int) -> CGPoint {
        CGPoint(x: CGFloat(level) * 3, y: CGFloat(level) * -4)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func arcPosition(from: CGPoint, to: CGPoint, progress t: CGFloat, height: CGFloat) -> CGPoint {
        let eased = easeInOut(t)
        let x = from.x + (to.x - from.x) * eased
        let y = from.y + (to.y - from.y) * eased - sin(eased * .pi) * height
        return CGPoint(x: x, y: y)
    }

    private func arcScale(_ t: CGFloat) -> CGFloat {
        sin(t * .pi)
    }

    /// Overflown-tile glow envelope: fade in, hold, fade out over the hop.
    private func jumpGlow(_ t: CGFloat) -> CGFloat {
        sin(min(1, t * 1.15) * .pi)
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    // MARK: - Animation Filtering

    private func isHiddenByAnimation(_ rt: RenderedTile) -> Bool {
        switch game.animationPhase {
        case .travel(let piece, let path):
            return rt.hex == path.from && rt.piece.id == piece.id && rt.isTop
        case .drop(_, let at):
            return rt.hex == at && rt.isTop
        case .none:
            return false
        }
    }

    /// The rejection sequence number when this exact tile was just rejected —
    /// the change in value is what triggers the tile's shake animation.
    private func rejectedSeq(for rt: RenderedTile) -> Int? {
        guard let rejection = game.rejection, rejection.hex == rt.hex, rt.isTop else { return nil }
        return rejection.seq
    }

    /// Tiles enter with a scale-pop normally; under Reduce Motion they simply
    /// fade so no movement is introduced.
    private var tileTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity)
    }

    /// VoiceOver description of a board tile: colour + bug (+ whether it is
    /// buried under another tile, since buried tiles can't be acted on).
    private func accessibilityLabel(for rt: RenderedTile) -> Text {
        let colorName = rt.piece.color == .white ? "branca" : "preta"
        var label = "Peça \(colorName): \(rt.piece.bug.displayName)"
        if !rt.isTop { label += ", coberta por outra peça" }
        return Text(label)
    }

    // MARK: - Queen Danger

    private func queenHex(for color: PlayerColor) -> Hex? {
        for hex in game.state.board.occupiedCells {
            if let top = game.state.board.topPiece(hex),
               top.bug == .queen && top.color == color {
                return hex
            }
        }
        return nil
    }

    private func coveredSides(of hex: Hex, color: PlayerColor) -> Int {
        let board = game.state.board
        let opponent: PlayerColor = color == .white ? .black : .white
        return hex.neighbors.filter { neighbor in
            guard let top = board.topPiece(neighbor) else { return false }
            return top.color == opponent
        }.count
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

    // MARK: - Drag & Drop

    /// A drag gesture on a board tile: requires a short hold (0.3s) so it
    /// doesn't conflict with the immediate pan gesture. Fires `beginDrag` once,
    /// then continuously updates the finger position for the ghost.
    private func tileDragGesture(_ rt: RenderedTile) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .second(true, let dragValue):
                    if !game.dragState.isDragging, rt.isTop {
                        game.beginDrag(.board(pieceID: rt.piece.id, from: rt.hex))
                    }
                    if let dragValue {
                        game.dragState.fingerPosition = dragValue.location
                        // Update hovered hex from finger position
                        let boardPt = globalToBoardHex(dragValue.location)
                        game.dragState.hoveredHex = game.dragState.validTargets.contains(boardPt) ? boardPt : nil
                    }
                default: break
                }
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
    }

    /// True when the rendered tile is the source of the active drag — it should
    /// be dimmed to show it has been "lifted".
    private func isDragSource(_ rt: RenderedTile) -> Bool {
        guard rt.isTop else { return false }
        if case let .board(id, from) = game.dragState.source {
            return rt.piece.id == id && rt.hex == from
        }
        return false
    }

    /// Converts a global finger position to a hex coordinate on the board by
    /// reversing the zoom/pan/center transforms the content layer applies.
    private func globalToBoardHex(_ globalPos: CGPoint) -> Hex {
        let scale = zoom * pinch
        let offsetX = pan.width + drag.width
        let offsetY = pan.height + drag.height
        // globalPos is in the BoardView's coordinate space (via .global, then
        // into our GeometryReader). We need to invert: content is positioned at
        // center, then scaled, then offset.
        let boardX = (globalPos.x - boardCenter.x - offsetX) / scale
        let boardY = (globalPos.y - boardCenter.y - offsetY) / scale
        return layout.hex(for: CGPoint(x: boardX, y: boardY))
    }

    /// Ghost tile floating under the finger during a drag. Rendered at the root
    /// ZStack level (not inside the scaled content) so it stays a consistent
    /// size regardless of the board zoom.
    @ViewBuilder
    private func dragGhostOverlay(center: CGPoint, geoSize: CGSize) -> some View {
        if let piece = game.dragState.piece, game.dragState.isDragging {
            let pos = game.dragState.fingerPosition
            TileView(piece: piece, size: baseHexSize)
                .opacity(0.75)
                .scaleEffect(1.12)
                .shadow(color: HiveTheme.selection.opacity(0.5), radius: 12, y: 4)
                .position(pos)
                .zIndex(3000)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Pulsing target markers for valid drop destinations during a drag.
    @ViewBuilder
    private func dragTargetsOverlay(center: CGPoint) -> some View {
        let targets = game.dragState.validTargets
        ForEach(Array(targets), id: \.self) { hex in
            let isHovered = game.dragState.hoveredHex == hex
            ZStack {
                TargetMarker(size: baseHexSize)
                if isHovered {
                    RegularHexagon()
                        .fill(HiveTheme.target.opacity(0.35))
                        .frame(width: baseHexSize * sqrt(3), height: baseHexSize * 2)
                }
            }
            .position(layout.point(for: hex) + center)
            .zIndex(500)
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

/// Pulsing marker drawn on an empty cell that is a legal destination. Under
/// Reduce Motion it renders steady (no pulsing) but stays clearly visible.
private struct TargetMarker: View {
    let size: CGFloat
    @State private var pulse = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RegularHexagon()
                .fill(HiveTheme.target.opacity(0.16))
                .scaleEffect(breathe ? 1.04 : 0.96)
            Circle()
                .fill(HiveTheme.target.opacity(0.9))
                .frame(width: size * 0.5, height: size * 0.5)
                .scaleEffect(pulse ? 1.15 : 0.85)
        }
        .frame(width: size * sqrt(3), height: size * 2)
        .contentShape(RegularHexagon())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

/// Progress ring around a queen showing how many sides the opponent covers.
private struct QueenDangerRing: View {
    let coveredSides: Int
    let color: PlayerColor
    let size: CGFloat
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let danger = coveredSides >= 4
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Angle.degrees(Double(i) * 60 - 90)
                let radius = size * 1.05
                let isCovered = i < coveredSides
                Capsule()
                    .fill(isCovered ? HiveTheme.danger : Color.white.opacity(0.08))
                    .frame(width: size * 0.28, height: size * 0.08)
                    .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
                    .rotationEffect(angle + .degrees(90))
                    .opacity(isCovered ? (danger ? (glow ? 1.0 : 0.6) : 0.85) : 0.3)
            }
        }
        .frame(width: size * sqrt(3), height: size * 2)
        .onAppear {
            if danger && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
    }
}

/// Pulsing glow around the currently selected board piece.
private struct SelectedAura: View {
    let color: PlayerColor
    let size: CGFloat
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RegularHexagon()
            .stroke(HiveTheme.selection, lineWidth: 2.5)
            .frame(width: size * sqrt(3) * 1.08, height: size * 2 * 1.08)
            .opacity(pulse ? 0.9 : 0.35)
            .scaleEffect(pulse ? 1.06 : 0.97)
            .shadow(color: HiveTheme.selection.opacity(0.5), radius: pulse ? 8 : 3)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

/// Glowing marker on the cell a hint suggests playing to. Distinct from the
/// green legal-move `TargetMarker`: gold, with a sparkle, so a suggestion reads
/// as "look at this" rather than "you picked this". Tapping it plays the hint.
private struct HintMarker: View {
    let size: CGFloat
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gold: Color { HiveTheme.accent(.queen) }

    var body: some View {
        ZStack {
            RegularHexagon()
                .fill(gold.opacity(0.20))
            RegularHexagon()
                .stroke(gold, lineWidth: 2.5)
                .scaleEffect(pulse ? 1.05 : 0.97)
                .shadow(color: gold.opacity(0.7), radius: pulse ? 9 : 4)
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(gold)
                .scaleEffect(pulse ? 1.1 : 0.92)
        }
        .frame(width: size * sqrt(3), height: size * 2)
        .contentShape(RegularHexagon())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Soft ring around the piece a hint wants to move (placements glow the hand
/// chip instead). Purely decorative — the destination `HintMarker` is the call
/// to action.
private struct HintSourceRing: View {
    let size: CGFloat
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gold: Color { HiveTheme.accent(.queen) }

    var body: some View {
        RegularHexagon()
            .stroke(gold.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            .frame(width: size * sqrt(3) * 1.12, height: size * 2 * 1.12)
            .opacity(pulse ? 0.95 : 0.5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
