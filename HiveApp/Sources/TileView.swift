import SwiftUI
import HiveEngine

/// A single hexagonal tile: player-coloured hexagon with the bug's emblem.
struct TileView: View {
    let piece: Piece
    let size: CGFloat
    var selected: Bool = false
    var lastMoved: Bool = false
    var isBeetleTarget: Bool = false

    private var layout: HexLayout { HexLayout(size: size) }

    var body: some View {
        ZStack {
            RegularHexagon()
                .fill(HiveTheme.tileGradient(piece.color))
                .overlay(
                    RegularHexagon()
                        .stroke(HiveTheme.tileBorder(piece.color), lineWidth: max(1, size * 0.06))
                )
                .overlay(ringOverlay)
                .shadow(color: .black.opacity(0.35), radius: size * 0.14, x: 0, y: size * 0.10)

            emblem
        }
        .frame(width: layout.tileWidth, height: layout.tileHeight)
        .contentShape(RegularHexagon())
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

    private var emblem: some View {
        let accent = HiveTheme.accent(piece.bug)
        return ZStack {
            Circle()
                .fill(accent.gradient)
                .frame(width: size * 1.02, height: size * 1.02)
                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: size * 0.05))
                .shadow(color: accent.opacity(0.5), radius: size * 0.12)

            Image(systemName: HiveTheme.symbol(piece.bug))
                .font(.system(size: size * 0.62, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        // Small letter badge so the species is unambiguous even at a glance.
        .overlay(alignment: .bottomTrailing) {
            Text(piece.bug.letter)
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(HiveTheme.ink(piece.color))
                .padding(size * 0.10)
                .background(Circle().fill(HiveTheme.tileGradient(piece.color)))
                .overlay(Circle().stroke(HiveTheme.tileBorder(piece.color), lineWidth: 1))
                .offset(x: size * 0.42, y: size * 0.42)
        }
    }
}
