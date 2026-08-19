import Foundation

/// A reconstructed step-by-step route for a legal piece move, so the app can
/// animate the move the way the bug actually travels — the Ant slides hex by
/// hex around the hive, the Spider visibly walks its three steps, the
/// Grasshopper arcs over the line it jumps, the Ladybug climbs two tiles and
/// drops off the second, the Beetle changes stack level.
///
/// `MoveGenerator.destinations` only answers *where* a tile may end up; this
/// answers *how it gets there*.
public struct MovePath: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Ground slide along the hive wall, one gate at a time
        /// (Queen 1 step, Spider exactly 3, Ant the shortest route).
        case slide
        /// Straight-line hop over a contiguous run of tiles (Grasshopper).
        /// Intermediate steps are the overflown tiles, not stops.
        case jump
        /// Single step that may change stack level (Beetle, or a Mosquito
        /// copying one from atop the hive).
        case climb
        /// Climb onto the hive, cross one more tile along the roof, then drop
        /// to the ground on the far side (Ladybug).
        case overTheTop
    }

    public struct Step: Equatable, Sendable {
        public let hex: Hex
        /// Stack level the travelling tile occupies at this point: the number
        /// of tiles beneath it (0 = ground). For `.jump` intermediates this is
        /// the level of the tile being flown over (used to highlight it).
        public let level: Int

        public init(hex: Hex, level: Int) {
            self.hex = hex
            self.level = level
        }
    }

    public let kind: Kind
    /// The full route: origin first, destination last, intermediates between.
    public let steps: [Step]

    public init(kind: Kind, steps: [Step]) {
        self.kind = kind
        self.steps = steps
    }

    public var from: Hex { steps.first?.hex ?? .origin }
    public var to: Hex { steps.last?.hex ?? .origin }
}
