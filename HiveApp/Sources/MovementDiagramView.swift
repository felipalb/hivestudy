import SwiftUI
import HiveEngine

/// An animated mini-board that visually demonstrates how a bug moves, shown
/// inside the piece-inspection overlay. Each bug gets a tiny self-contained
/// scenario and a looping animation: the piece visibly walks / slides / hops
/// its canonical pattern so the player *sees* the rule in action rather than
/// just reading about it.
///
/// The view is purely decorative — no interaction, no game state, just
/// a `TimelineView` driving a piece along a pre-baked route.
struct MovementDiagramView: View {
    let bug: Bug
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hexSize: CGFloat = 14

    var body: some View {
        let scenario = Self.scenario(for: bug)
        let layout = HexLayout(size: hexSize)

        // Compute bounds to center the diagram
        let allHexes = scenario.staticTiles.map(\.hex) + scenario.route
        let pts = allHexes.map { layout.point(for: $0) }
        let minX = pts.map(\.x).min() ?? 0, maxX = pts.map(\.x).max() ?? 0
        let minY = pts.map(\.y).min() ?? 0, maxY = pts.map(\.y).max() ?? 0
        let centroid = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let boundsW = (maxX - minX) + hexSize * sqrt(3) * 1.6
        let boundsH = (maxY - minY) + hexSize * 2 * 1.6

        Group {
            if reduceMotion {
                diagramCanvas(t: 0.5, scenario: scenario, layout: layout, centroid: centroid)
            } else {
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let cycleDuration = scenario.cycleDuration
                    let t = now.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                    diagramCanvas(t: t, scenario: scenario, layout: layout, centroid: centroid)
                }
            }
        }
        .frame(width: boundsW, height: boundsH)
        .frame(maxWidth: 220, maxHeight: 140)
    }

    private func diagramCanvas(t: CGFloat, scenario: DiagramScenario, layout: HexLayout, centroid: CGPoint) -> some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width / 2 - centroid.x, y: size.height / 2 - centroid.y)

            // Draw static tiles
            for tile in scenario.staticTiles {
                let pos = layout.point(for: tile.hex) + origin
                drawHex(context: context, at: pos, color: tile.color, bug: tile.bug, size: hexSize)
            }

            // Draw route trail (faint hex outlines showing where the piece can go)
            for hex in scenario.route {
                let pos = layout.point(for: hex) + origin
                let hexPath = hexPath(at: pos, size: hexSize)
                context.stroke(hexPath, with: .color(.white.opacity(0.12)), lineWidth: 1)
            }

            // Draw moving piece
            let moveT = movingPieceProgress(t: t, scenario: scenario)
            let piecePos = interpolateRoute(scenario.route, progress: moveT, layout: layout, origin: origin, kind: scenario.kind)
            drawHex(context: context, at: piecePos, color: scenario.pieceColor, bug: bug, size: hexSize, isGhost: false)

            // Subtle glow under moving piece
            let glowRect = CGRect(x: piecePos.x - hexSize * 0.7, y: piecePos.y - hexSize * 0.7,
                                  width: hexSize * 1.4, height: hexSize * 1.4)
            context.fill(
                Circle().path(in: glowRect),
                with: .color(HiveTheme.selection.opacity(0.18 + sin(t * .pi * 2) * 0.08))
            )
        }
    }

    // MARK: - Drawing Helpers

    private func hexPath(at pos: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let r = size
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: pos.x + r * cos(angle), y: pos.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func drawHex(context: GraphicsContext, at pos: CGPoint, color: PlayerColor, bug: Bug, size: CGFloat, isGhost: Bool = false) {
        let path = hexPath(at: pos, size: size)
        let topColor = color == .white ? HiveTheme.whiteTileTop : HiveTheme.blackTileTop
        let borderColor = color == .white ? HiveTheme.whiteTileBorder : HiveTheme.blackTileBorder

        var ctx = context
        if isGhost { ctx.opacity = 0.5 }
        ctx.fill(path, with: .color(topColor))
        ctx.stroke(path, with: .color(borderColor), lineWidth: 1)

        // Draw bug icon (simplified — just the accent-colored circle with letter)
        let accent = HiveTheme.accent(bug, on: color)
        let textSize = size * 0.65
        let text = Text(bug.letter)
            .font(.system(size: textSize, weight: .black, design: .rounded))
            .foregroundColor(accent)
        ctx.draw(text, at: pos)
    }

    // MARK: - Animation Math

    /// The portion [0,1] of the cycle spent actually moving (vs. pausing at endpoints).
    private func movingPieceProgress(t: CGFloat, scenario: DiagramScenario) -> CGFloat {
        // 70% of cycle is movement, 15% pause at start, 15% pause at end
        let pauseFraction: CGFloat = 0.15
        let moveFraction: CGFloat = 1.0 - pauseFraction * 2

        if t < pauseFraction { return 0 }
        if t > 1.0 - pauseFraction { return 1 }
        return (t - pauseFraction) / moveFraction
    }

    /// Interpolate a position along the route at `progress` ∈ [0,1].
    private func interpolateRoute(_ route: [Hex], progress: CGFloat, layout: HexLayout, origin: CGPoint, kind: MovePath.Kind) -> CGPoint {
        guard route.count > 1 else {
            let firstHex = route.first ?? .origin
            let pt = layout.point(for: firstHex)
            return CGPoint(x: pt.x + origin.x, y: pt.y + origin.y)
        }

        var points: [CGPoint] = []
        for hex in route {
            let pt = layout.point(for: hex)
            points.append(CGPoint(x: pt.x + origin.x, y: pt.y + origin.y))
        }

        let eased: CGFloat = easeInOut(progress)

        switch kind {
        case .jump:
            let from = points.first ?? .zero
            let to = points.last ?? .zero
            let x = from.x + (to.x - from.x) * eased
            let countOffset: CGFloat = CGFloat(max(0, route.count - 2)) * 8.0
            let hopH: CGFloat = min(48.0, 24.0 + countOffset)
            let arcOffset: CGFloat = sin(eased * .pi) * hopH
            let y = from.y + (to.y - from.y) * eased - arcOffset
            return CGPoint(x: x, y: y)

        case .overTheTop:
            var lifted = points
            if route.count >= 4 {
                let liftDelta: CGFloat = hexSize * 0.8
                lifted[1] = CGPoint(x: lifted[1].x, y: lifted[1].y - liftDelta)
                lifted[2] = CGPoint(x: lifted[2].x, y: lifted[2].y - liftDelta)
            }
            return polylinePosition(points: lifted, progress: eased)

        case .climb:
            let from = points.first ?? .zero
            let to = points.last ?? .zero
            let x = from.x + (to.x - from.x) * eased
            let climbDelta: CGFloat = sin(eased * .pi) * (hexSize * 0.6)
            let y = from.y + (to.y - from.y) * eased - climbDelta
            return CGPoint(x: x, y: y)

        case .slide:
            return polylinePosition(points: points, progress: eased)
        }
    }

    private func polylinePosition(points: [CGPoint], progress: CGFloat) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let segments = CGFloat(points.count - 1)
        let scaled = min(progress, 0.9999) * segments
        let index = Int(scaled)
        let local = easeInOut(scaled - CGFloat(index))
        let a = points[index], b = points[index + 1]
        let x = a.x + (b.x - a.x) * local
        let y = a.y + (b.y - a.y) * local
        return CGPoint(x: x, y: y)
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 2.0 * t * t
        } else {
            let factor = -2.0 * t + 2.0
            return 1.0 - (factor * factor) / 2.0
        }
    }

    // MARK: - Scenarios

    struct DiagramTile {
        let hex: Hex
        let bug: Bug
        let color: PlayerColor
    }

    struct DiagramScenario {
        let staticTiles: [DiagramTile]
        /// The route the animated piece follows: first element is start, last is end.
        let route: [Hex]
        let kind: MovePath.Kind
        let pieceColor: PlayerColor
        /// Total cycle duration in seconds (movement + pauses)
        var cycleDuration: TimeInterval = 3.0
    }

    static func scenario(for bug: Bug) -> DiagramScenario {
        switch bug {
        case .queen:     return queenScenario()
        case .ant:       return antScenario()
        case .spider:    return spiderScenario()
        case .grasshopper: return grasshopperScenario()
        case .beetle:    return beetleScenario()
        case .ladybug:   return ladybugScenario()
        case .mosquito:  return mosquitoScenario()
        case .pillbug:   return pillbugScenario()
        }
    }

    // MARK: Per-Bug Scenarios

    /// Queen moves exactly 1 space — shows a short slide to an adjacent cell.
    private static func queenScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .spider, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .ant, color: .black),
                DiagramTile(hex: Hex(0, 1), bug: .beetle, color: .white),
            ],
            route: [Hex(-1, 0), Hex(-1, 1)],
            kind: .slide,
            pieceColor: .white,
            cycleDuration: 2.5
        )
    }

    /// Ant slides freely around the hive — loops around a small cluster.
    private static func antScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .queen, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .spider, color: .white),
                DiagramTile(hex: Hex(1, -1), bug: .beetle, color: .black),
            ],
            route: [Hex(0, -1), Hex(-1, 0), Hex(-1, 1), Hex(0, 1), Hex(1, 1), Hex(2, 0), Hex(2, -1)],
            kind: .slide,
            pieceColor: .white,
            cycleDuration: 4.0
        )
    }

    /// Spider walks exactly 3 steps along the hive wall.
    private static func spiderScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .queen, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .ant, color: .black),
                DiagramTile(hex: Hex(2, 0), bug: .beetle, color: .white),
            ],
            route: [Hex(-1, 0), Hex(-1, 1), Hex(0, 1), Hex(1, 1)],
            kind: .slide,
            pieceColor: .white,
            cycleDuration: 3.5
        )
    }

    /// Grasshopper jumps in a straight line over tiles.
    private static func grasshopperScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .queen, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .ant, color: .white),
                DiagramTile(hex: Hex(2, 0), bug: .spider, color: .black),
            ],
            route: [Hex(-1, 0), Hex(0, 0), Hex(1, 0), Hex(2, 0), Hex(3, 0)],
            kind: .jump,
            pieceColor: .white,
            cycleDuration: 2.5
        )
    }

    /// Beetle climbs on top of an adjacent tile.
    private static func beetleScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .queen, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .ant, color: .white),
            ],
            route: [Hex(-1, 0), Hex(0, 0)],
            kind: .climb,
            pieceColor: .white,
            cycleDuration: 2.5
        )
    }

    /// Ladybug: up onto the hive, across one tile, down to the ground.
    private static func ladybugScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .queen, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .ant, color: .white),
                DiagramTile(hex: Hex(1, -1), bug: .spider, color: .black),
            ],
            route: [Hex(-1, 0), Hex(0, 0), Hex(1, 0), Hex(2, 0)],
            kind: .overTheTop,
            pieceColor: .white,
            cycleDuration: 3.5
        )
    }

    /// Mosquito: copies adjacent bugs — shows a "?" theme with a gentle pulse.
    private static func mosquitoScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .ant, color: .black),
                DiagramTile(hex: Hex(1, 0), bug: .spider, color: .white),
            ],
            // Mosquito slides like the ant it's touching — a short slide
            route: [Hex(-1, 0), Hex(-1, 1), Hex(0, 1)],
            kind: .slide,
            pieceColor: .white,
            cycleDuration: 3.0
        )
    }

    /// Pillbug: no movement rules implemented — static display.
    private static func pillbugScenario() -> DiagramScenario {
        DiagramScenario(
            staticTiles: [
                DiagramTile(hex: Hex(0, 0), bug: .queen, color: .black),
            ],
            route: [Hex(-1, 0)],
            kind: .slide,
            pieceColor: .white,
            cycleDuration: 3.0
        )
    }
}
