import SwiftUI
import HiveEngine

// MARK: - Drag State

/// Tracks an in-progress drag of a piece — from the hand tray onto the board, or
/// from one board cell to another. Lives on `GameController` so both `HandTrayView`
/// and `BoardView` can read/write it, and the ghost overlay (hosted on `ContentView`)
/// can render the floating tile.
@MainActor
@Observable
final class DragState {
    /// Where the drag originated.
    enum Source: Equatable {
        case hand(Bug, PlayerColor)
        case board(pieceID: Int, from: Hex)
    }

    private(set) var source: Source?
    private(set) var piece: Piece?
    /// Legal destinations for the dragged piece — the same set `GameController.targets`
    /// would hold for a tap selection.
    private(set) var validTargets: Set<Hex> = []

    /// The finger's current position in the **root coordinate space** (`ContentView`).
    /// Updated every frame during the drag; the ghost overlay reads this to follow
    /// the finger.
    var fingerPosition: CGPoint = .zero

    /// The hex the finger is currently hovering over (updated each frame from the
    /// board's coordinate-space transform). `nil` when the finger is outside the
    /// board or over a non-target cell.
    var hoveredHex: Hex?

    var isDragging: Bool { source != nil }

    func begin(source: Source, piece: Piece, targets: Set<Hex>) {
        self.source = source
        self.piece = piece
        self.validTargets = targets
        self.hoveredHex = nil
    }

    func reset() {
        source = nil
        piece = nil
        validTargets = []
        hoveredHex = nil
        fingerPosition = .zero
    }
}
