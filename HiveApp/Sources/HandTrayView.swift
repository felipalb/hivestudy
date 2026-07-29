import SwiftUI
import HiveEngine

/// A player's remaining tiles, tappable to pick one for placement.
struct HandTrayView: View {
    let game: GameController
    let color: PlayerColor

    private var isActive: Bool {
        game.current == color && game.result == .ongoing && game.humanControls(color) && !game.isThinking
    }

    private var hand: [(bug: Bug, count: Int)] { game.state.hand(color) }

    var body: some View {
        HStack(spacing: 10) {
            label
            if hand.isEmpty {
                Text("No tiles in hand")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hand, id: \.bug) { entry in
                            HandChip(
                                bug: entry.bug,
                                color: color,
                                count: entry.count,
                                selected: isSelected(entry.bug),
                                enabled: isActive && isPlaceable(entry.bug)
                            )
                            .onTapGesture { game.selectHand(entry.bug, color) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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
        .frame(width: 46)
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

    private let size: CGFloat = 24

    var body: some View {
        TileView(piece: Piece(id: -1, bug: bug, color: color), size: size, selected: selected)
            .frame(width: size * sqrt(3) + 6, height: size * 2)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
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
