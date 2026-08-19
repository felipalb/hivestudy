import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// A player's remaining tiles, displayed in a spacious two-tier layout:
/// - Top row: Queen, Spider, Beetle
/// - Bottom row: Grasshopper, Ant, Mosquito, Ladybug (starting from Grasshopper)
///
/// Enlarged pieces with zero scrolling for maximum legibility and comfort.
struct HandTrayView: View {
    let game: GameController
    let color: PlayerColor
    /// Press-and-hold on a chip asks the root to explain that bug's movement.
    var onInspectPiece: (Piece) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let chipSize: CGFloat = 34
    private let chipSpacing: CGFloat = 8
    private let rowSpacing: CGFloat = 6

    private var isActive: Bool {
        game.current == color && game.result == .ongoing && game.humanControls(color) && !game.isThinking
    }

    private var hand: [(bug: Bug, count: Int)] { game.state.hand(color) }

    private var topRowBugs: [(bug: Bug, count: Int)] {
        let topTypes: Set<Bug> = [.queen, .spider, .beetle]
        return hand.filter { topTypes.contains($0.bug) }
    }

    private var bottomRowBugs: [(bug: Bug, count: Int)] {
        let topTypes: Set<Bug> = [.queen, .spider, .beetle]
        return hand.filter { !topTypes.contains($0.bug) }
    }

    var body: some View {
        Group {
            if hand.isEmpty {
                Text("Sem peças na mão")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: rowSpacing) {
                    if !topRowBugs.isEmpty {
                        chipRow(topRowBugs)
                    }
                    if !bottomRowBugs.isEmpty {
                        chipRow(bottomRowBugs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isActive ? HiveTheme.selection.opacity(0.85) : .white.opacity(0.08),
                                lineWidth: isActive ? 2 : 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    /// One tappable row of hand chips.
    private func chipRow(_ bugs: [(bug: Bug, count: Int)]) -> some View {
        HStack(spacing: chipSpacing) {
            ForEach(bugs, id: \.bug) { entry in
                HandChip(
                    bug: entry.bug,
                    color: color,
                    count: entry.count,
                    selected: isSelected(entry.bug),
                    hinted: isHinted(entry.bug),
                    enabled: isActive && isPlaceable(entry.bug),
                    size: chipSize,
                    isDragging: isDraggingThisChip(entry.bug)
                )
                .onTapGesture { game.selectHand(entry.bug, color) }
                .onLongPressGesture(minimumDuration: 0.4) { inspect(entry.bug) }
                .gesture(chipDragGesture(entry.bug))
                .transition(chipTransition)
                .accessibilityLabel(accessibilityLabel(for: entry))
                .accessibilityAddTraits(isActive && isPlaceable(entry.bug) ? .isButton : [])
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: bugs.map(\.bug))
    }

    /// A drag that lifts a hand chip towards the board. Starts after a short
    /// distance to distinguish from taps; fires `beginDrag` once, then
    /// continuously updates the finger position so the ghost follows the finger.
    private func chipDragGesture(_ bug: Bug) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                if !game.dragState.isDragging {
                    guard isActive, isPlaceable(bug) else { return }
                    game.beginDrag(.hand(bug, color))
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
    }

    private func isDraggingThisChip(_ bug: Bug) -> Bool {
        if case let .hand(b, c) = game.dragState.source, b == bug, c == color { return true }
        return false
    }

    private var chipTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.3).combined(with: .opacity),
                removal: .scale(scale: 0.1).combined(with: .opacity)
            )
    }

    private func isHinted(_ bug: Bug) -> Bool {
        color == game.current && game.hintHandBug == bug
    }

    private func accessibilityLabel(for entry: (bug: Bug, count: Int)) -> String {
        let colorName = color == .white ? "brancas" : "pretas"
        let count = entry.count == 1 ? "1 peça restante" : "\(entry.count) peças restantes"
        return "\(entry.bug.displayName), \(colorName), \(count)"
    }

    private func inspect(_ bug: Bug) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
        onInspectPiece(Piece(id: -1, bug: bug, color: color))
    }

    private func isSelected(_ bug: Bug) -> Bool {
        if case let .hand(b, c) = game.selection { return b == bug && c == color }
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
    var hinted: Bool = false
    let enabled: Bool
    let size: CGFloat

    /// True while this chip is being dragged — dims the source to show it's "lifted".
    var isDragging: Bool = false

    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TileView(piece: Piece(id: -1, bug: bug, color: color), size: size, selected: selected)
            .frame(width: size * sqrt(3) + 6, height: size * 2)
            .overlay { hintGlow }
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: max(11, size * 0.36), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(Capsule().fill(.black.opacity(0.8)))
                        .overlay(Capsule().stroke(HiveTheme.selection.opacity(0.5), lineWidth: 1))
                        .offset(x: 4, y: -2)
                }
            }
            .opacity(isDragging ? 0.3 : (enabled ? 1 : 0.4))
            .scaleEffect(selected ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
            .onChange(of: hinted) { _, isHinted in
                guard isHinted, !reduceMotion else { glow = false; return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
            .onAppear {
                guard hinted, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }

    /// Golden pulsing outline when the active hint wants to place this bug.
    @ViewBuilder private var hintGlow: some View {
        if hinted {
            RegularHexagon()
                .stroke(HiveTheme.accent(.queen), lineWidth: 2.5)
                .shadow(color: HiveTheme.accent(.queen).opacity(0.85), radius: glow ? 10 : 4)
                .opacity(glow ? 1.0 : 0.6)
                .allowsHitTesting(false)
        }
    }
}
