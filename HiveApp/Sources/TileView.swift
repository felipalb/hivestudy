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

    /// The tile shows the bug's own icon above its actual name (not an initial),
    /// both tinted in the bug's signature colour, sitting directly on the plain
    /// black/white tile — no separate coloured plaque behind them.
    /// (Split into sub-expressions to keep the Swift type-checker fast.)
    private var emblem: some View {
        let fontSize: CGFloat = size * 0.24
        let name = Text(piece.bug.tileName)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .minimumScaleFactor(0.35)
            .lineLimit(1)
        let icon = BugIcon(bug: piece.bug)
            .frame(width: size * 0.56, height: size * 0.56)
        return VStack(spacing: size * 0.05) {
            icon
            name
        }
        .foregroundStyle(HiveTheme.accent(piece.bug, on: piece.color))
        .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
        .frame(maxWidth: layout.tileWidth * 0.92)
    }
}
