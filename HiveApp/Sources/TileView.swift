import SwiftUI
import HiveEngine

/// A single hexagonal tile: player-coloured hexagon with the bug's emblem.
struct TileView: View {
    let piece: Piece
    let size: CGFloat
    var selected: Bool = false
    var lastMoved: Bool = false
    var isBeetleTarget: Bool = false
    var isCutVertex: Bool = false
    /// Increments every time this tile's tap is rejected (e.g. an opponent's
    /// piece) — each increment shakes the tile so the "no" is visible.
    var rejectedSeq: Int? = nil

    @State private var shakePhase: CGFloat = 0
    @State private var cutVertexPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: HexLayout { HexLayout(size: size) }

    var body: some View {
        ZStack {
            tileImage
            nameBadge
            cutVertexGlow
        }
        .frame(width: layout.tileWidth, height: layout.tileHeight)
        .modifier(ShakeEffect(animatableData: shakePhase))
        .contentShape(RegularHexagon())
        .onAppear {
            if isCutVertex && !reduceMotion {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                    cutVertexPulse = true
                }
            }
        }
        .onChange(of: isCutVertex) { _, newValue in
            if newValue && !reduceMotion {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                    cutVertexPulse = true
                }
            }
        }
        .onChange(of: rejectedSeq) { oldValue, newValue in
            guard let newValue, newValue != oldValue else { return }
            withAnimation(.linear(duration: reduceMotion ? 0.12 : 0.36)) {
                shakePhase += reduceMotion ? 0.5 : 3
            }
        }
    }

    private var tileBorderColor: Color {
        piece.color == .white
            ? Color(red: 0.95, green: 0.85, blue: 0.60).opacity(0.85)
            : Color(red: 1.0, green: 0.70, blue: 0.20).opacity(0.85)
    }

    private var tileShadowColor: Color {
        piece.color == .white
            ? Color.black.opacity(0.4)
            : Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.35)
    }

    private var tileImage: some View {
        Image(pieceImageName(for: piece))
            .resizable()
            .scaledToFill()
            .frame(width: layout.tileWidth, height: layout.tileHeight)
            .clipShape(RegularHexagon())
            .overlay(
                RegularHexagon()
                    .stroke(tileBorderColor, lineWidth: max(1.2, size * 0.06))
            )
            .overlay(ringOverlay)
            .shadow(color: tileShadowColor, radius: size * 0.16, x: 0, y: size * 0.08)
    }

    private var nameBadge: some View {
        let isWhite = piece.color == .white
        let textColor = isWhite
            ? Color(red: 0.30, green: 0.20, blue: 0.05)
            : Color(red: 1.0, green: 0.88, blue: 0.45)
        let bgFill = isWhite
            ? Color.white.opacity(0.92)
            : Color.black.opacity(0.85)
        let borderStroke = isWhite
            ? Color(red: 0.8, green: 0.7, blue: 0.5).opacity(0.55)
            : Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.65)

        return VStack {
            Spacer()
            Text(piece.bug.tileName)
                .font(.system(size: max(7.5, size * 0.165), weight: .heavy, design: .rounded))
                .tracking(0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .foregroundStyle(textColor)
                .padding(.horizontal, max(3.5, size * 0.075))
                .padding(.vertical, max(1, size * 0.022))
                .background(
                    Capsule()
                        .fill(bgFill)
                        .overlay(Capsule().stroke(borderStroke, lineWidth: 0.75))
                )
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.8)
                .padding(.bottom, size * 0.26)
        }
        .frame(maxWidth: layout.tileWidth * 0.75)
    }

    @ViewBuilder private var ringOverlay: some View {
        if selected {
            RegularHexagon().stroke(HiveTheme.selection, lineWidth: size * 0.14)
        } else if isBeetleTarget {
            RegularHexagon().stroke(HiveTheme.target, lineWidth: size * 0.14)
        } else if lastMoved {
            RegularHexagon().stroke(HiveTheme.lastMove, lineWidth: size * 0.07)
        }
    }

    @ViewBuilder private var cutVertexGlow: some View {
        if isCutVertex {
            RegularHexagon()
                .stroke(
                    Color(red: 0.95, green: 0.25, blue: 0.25).opacity(cutVertexPulse ? 0.65 : 0.18),
                    lineWidth: max(1.5, size * 0.08)
                )
                .shadow(
                    color: Color(red: 0.90, green: 0.20, blue: 0.20).opacity(cutVertexPulse ? 0.55 : 0.12),
                    radius: cutVertexPulse ? size * 0.14 : size * 0.04
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func pieceImageName(for piece: Piece) -> String {
        let colorSuffix = piece.color == .white ? "White" : "Black"
        switch piece.bug {
        case .queen: return "PieceLion" + colorSuffix
        case .ant: return "PieceCheetah" + colorSuffix
        case .spider: return "PieceZebra" + colorSuffix
        case .grasshopper: return "PieceKangaroo" + colorSuffix
        case .beetle: return "PieceGorilla" + colorSuffix
        case .ladybug: return "PieceEagle" + colorSuffix
        case .mosquito: return "PieceChameleon" + colorSuffix
        case .pillbug: return "PieceGorilla" + colorSuffix
        }
    }
}

/// Horizontal shake for rejected taps. `animatableData` advances by the number
/// of oscillations wanted (each integer step is one full left-right wiggle).
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 5 * sin(animatableData * 2 * .pi)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
