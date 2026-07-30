import SwiftUI
import HiveEngine

/// Colours and per-bug styling for the whole app.
///
/// Every colour lives in the asset catalog (`Assets.xcassets/Hive*.colorset`),
/// **not** as an RGB literal here — edit the palette in Xcode's asset editor.
/// See CLAUDE.md → "Colours & assets".
enum HiveTheme {
    // Table / background
    static let bgTop = Color("HiveBgTop")
    static let bgBottom = Color("HiveBgBottom")

    // Tiles
    static let whiteTileTop = Color("HiveWhiteTileTop")
    static let whiteTileBottom = Color("HiveWhiteTileBottom")
    static let whiteTileBorder = Color("HiveWhiteTileBorder")
    static let whiteInk = Color("HiveWhiteInk")

    static let blackTileTop = Color("HiveBlackTileTop")
    static let blackTileBottom = Color("HiveBlackTileBottom")
    static let blackTileBorder = Color("HiveBlackTileBorder")
    static let blackInk = Color("HiveBlackInk")

    // Feedback
    static let selection = Color("HiveSelection")
    static let target = Color("HiveTarget")
    static let lastMove = Color("HiveLastMove")
    static let danger = Color("HiveDanger")

    static func tileGradient(_ color: PlayerColor) -> LinearGradient {
        LinearGradient(
            colors: color == .white ? [whiteTileTop, whiteTileBottom] : [blackTileTop, blackTileBottom],
            startPoint: .top, endPoint: .bottom
        )
    }

    static func tileBorder(_ color: PlayerColor) -> Color {
        color == .white ? whiteTileBorder : blackTileBorder
    }

    static func ink(_ color: PlayerColor) -> Color {
        color == .white ? whiteInk : blackInk
    }

    /// Signature colour for each bug's name label.
    ///
    /// On the cream **white** tiles the Queen's bright yellow and the
    /// Grasshopper's mid-green wash out to near-invisibility, so those two get a
    /// darker, higher-contrast variant when drawn on a white tile
    /// (`HiveAccent…OnWhite`). Every other bug — and both bugs on black tiles —
    /// keeps its vivid signature colour. Pass the tile's colour via `on:`; omit
    /// it (the default) for contexts drawn on a dark background, e.g. the
    /// game-over crown, which should stay vivid.
    static func accent(_ bug: Bug, on tile: PlayerColor? = nil) -> Color {
        if tile == .white {
            switch bug {
            case .queen: return Color("HiveAccentQueenOnWhite")
            case .grasshopper: return Color("HiveAccentGrasshopperOnWhite")
            default: break
            }
        }
        switch bug {
        case .queen: return Color("HiveAccentQueen")
        case .ant: return Color("HiveAccentAnt")
        case .spider: return Color("HiveAccentSpider")
        case .beetle: return Color("HiveAccentBeetle")
        case .grasshopper: return Color("HiveAccentGrasshopper")
        case .mosquito: return Color("HiveAccentMosquito")
        case .ladybug: return Color("HiveAccentLadybug")
        case .pillbug: return Color("HiveAccentPillbug")
        }
    }
}
