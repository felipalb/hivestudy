import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// A player's remaining tiles, tappable to pick one for placement.
///
/// Tile size is computed from the available width (not fixed) so tiles read as
/// large as the screen allows — big enough that all six bug types fit in one
/// row without scrolling on most iPhones, while never shrinking below
/// `minChipSize`. On the narrowest phones that floor can force the row back
/// into a horizontal scroll; the `ScrollView` below is the fallback for that.
struct HandTrayView: View {
    let game: GameController
    let color: PlayerColor
    /// Press-and-hold on a chip asks the root to explain that bug's movement.
    var onInspectPiece: (Piece) -> Void = { _ in }

    private let labelWidth: CGFloat = 42
    private let rowSpacing: CGFloat = 10
    private let chipSpacing: CGFloat = 6
    private let minChipSize: CGFloat = 30
    private let maxChipSize: CGFloat = 44
    private let edgeFadeWidth: CGFloat = 14
    private let scrollEndInset: CGFloat = 16   // ≥ edgeFadeWidth so the first/last chip clears the fade

    private var isActive: Bool {
        game.current == color && game.result == .ongoing && game.humanControls(color) && !game.isThinking
    }

    private var hand: [(bug: Bug, count: Int)] { game.state.hand(color) }

    var body: some View {
        GeometryReader { geo in
            let raw = rawChipSize(for: geo.size.width)
            let chipSize = min(maxChipSize, max(minChipSize, raw))
            HStack(spacing: rowSpacing) {
                label
                if hand.isEmpty {
                    Text("No tiles in hand")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if raw < minChipSize {
                    // Cramped width: the row can't fit even at the minimum chip
                    // size, so it scrolls (e.g. a 6-type hand with the Mosquito).
                    // Chips stay comfortably sized, so two things keep the scroll
                    // from looking broken:
                    //   • end-insets give the first/last chip slack so a
                    //     *selected* chip's 1.08 scale, selection ring and count
                    //     badge are never hard-clipped at the viewport edge when
                    //     scrolled to either end; the vertical slack likewise
                    //     keeps the overhanging top badge from being cut off.
                    //   • `edgeFade` masks the ScrollView so its horizontal clip
                    //     reads as a soft fade instead of a broken border, and
                    //     signals that more tiles (the Mosquito) lie off-screen.
                    ScrollView(.horizontal, showsIndicators: false) {
                        chipRow(chipSize)
                            .padding(.horizontal, scrollEndInset)
                            .padding(.vertical, 6)
                    }
                    .mask(edgeFade)
                } else {
                    // Everything fits: render the row directly with no
                    // ScrollView. A ScrollView clips its content to its bounds,
                    // which cropped the edges of a *selected* chip (its 1.08
                    // scale, selection ring, and count badge). A plain HStack has
                    // no clip, so the whole chip stays visible.
                    chipRow(chipSize)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(height: maxChipSize * 2 + 6)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isActive ? HiveTheme.selection.opacity(0.8) : .white.opacity(0.08),
                                lineWidth: isActive ? 2 : 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    /// One tappable row of hand chips. Shared by the fits-in-one-row and the
    /// cramped-scroll branches so both stay identical bar the container.
    private func chipRow(_ chipSize: CGFloat) -> some View {
        HStack(spacing: chipSpacing) {
            ForEach(hand, id: \.bug) { entry in
                HandChip(
                    bug: entry.bug,
                    color: color,
                    count: entry.count,
                    selected: isSelected(entry.bug),
                    enabled: isActive && isPlaceable(entry.bug),
                    size: chipSize
                )
                .onTapGesture { game.selectHand(entry.bug, color) }
                // Same press-and-hold-to-inspect gesture as the board tiles, so
                // a hand chip (selected or not) reveals its movement rules too.
                .onLongPressGesture(minimumDuration: 0.4) { inspect(entry.bug) }
            }
        }
        .padding(.vertical, 2)
    }

    /// Fire a firm tactile tick and hand a display-only piece up to the root,
    /// which presents the movement-explanation modal.
    private func inspect(_ bug: Bug) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
        onInspectPiece(Piece(id: -1, bug: bug, color: color))
    }

    /// A soft fade at the leading/trailing edges of the scrolling tray. Used as
    /// the ScrollView's mask: the hard clip lands where alpha is ~0, so a chip
    /// sliding under an edge fades out instead of showing a broken border, and
    /// the fade doubles as an affordance that more tiles are off-screen. The
    /// edges are a fixed width (not a fraction of the row) so the fade looks
    /// identical on any tray width; the opaque black middle leaves every other
    /// chip fully visible.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: edgeFadeWidth)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: edgeFadeWidth)
        }
    }

    /// The chip size that would fit every hand tile across `totalWidth` in one
    /// row, **before** clamping. When it's below `minChipSize` the tiles can't
    /// fit and the row falls back to a horizontal scroll; otherwise the caller
    /// clamps it into `[minChipSize, maxChipSize]` and shows it without scrolling.
    private func rawChipSize(for totalWidth: CGFloat) -> CGFloat {
        guard !hand.isEmpty else { return minChipSize }
        let count = CGFloat(hand.count)
        let available = totalWidth - labelWidth - rowSpacing - chipSpacing * (count - 1)
        let perChipFrameWidth = available / count
        return (perChipFrameWidth - 6) / CGFloat(3).squareRoot()   // HandChip frame width = size*sqrt(3) + 6
    }

    private var label: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(HiveTheme.tileGradient(color))
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(HiveTheme.tileBorder(color), lineWidth: 1))
            Text(color == .white ? "White" : "Black")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: labelWidth)
    }

    private func isSelected(_ bug: Bug) -> Bool {
        if case let .hand(b, c) = game.selection { return b == bug && c == color }
        _ = color
        return false
    }

    private func isPlaceable(_ bug: Bug) -> Bool {
        if game.state.mustPlaceQueen { return bug == .queen }
        return true
    }
}

/// One stackable tile in the tray with a remaining-count badge.
private struct HandChip: View {
    let bug: Bug
    let color: PlayerColor
    let count: Int
    let selected: Bool
    let enabled: Bool
    let size: CGFloat

    var body: some View {
        TileView(piece: Piece(id: -1, bug: bug, color: color), size: size, selected: selected)
            .frame(width: size * sqrt(3) + 6, height: size * 2)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: max(10, size * 0.38), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .offset(x: 2, y: -2)
                }
            }
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(selected ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}
