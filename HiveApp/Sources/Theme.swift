import SwiftUI
import HiveEngine

/// Colours, fonts and per-bug styling for the whole app.
enum HiveTheme {
    // Table / background
    static let bgTop = Color(red: 0.11, green: 0.15, blue: 0.20)
    static let bgBottom = Color(red: 0.05, green: 0.08, blue: 0.12)

    // Tiles
    static let whiteTileTop = Color(red: 0.96, green: 0.94, blue: 0.87)
    static let whiteTileBottom = Color(red: 0.90, green: 0.86, blue: 0.76)
    static let whiteTileBorder = Color(red: 0.79, green: 0.72, blue: 0.57)
    static let whiteInk = Color(red: 0.16, green: 0.16, blue: 0.18)

    static let blackTileTop = Color(red: 0.22, green: 0.23, blue: 0.26)
    static let blackTileBottom = Color(red: 0.13, green: 0.13, blue: 0.16)
    static let blackTileBorder = Color(red: 0.36, green: 0.38, blue: 0.44)
    static let blackInk = Color(red: 0.95, green: 0.95, blue: 0.96)

    // Feedback
    static let selection = Color(red: 1.00, green: 0.83, blue: 0.29)
    static let target = Color(red: 0.20, green: 0.88, blue: 0.77)
    static let lastMove = Color.white.opacity(0.75)
    static let danger = Color(red: 0.94, green: 0.34, blue: 0.36)

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

    /// Signature colour for each bug's emblem disc.
    static func accent(_ bug: Bug) -> Color {
        switch bug {
        case .queen: return Color(red: 0.95, green: 0.72, blue: 0.05)
        case .ant: return Color(red: 0.18, green: 0.61, blue: 0.86)
        case .spider: return Color(red: 0.55, green: 0.37, blue: 0.24)
        case .beetle: return Color(red: 0.48, green: 0.38, blue: 1.00)
        case .grasshopper: return Color(red: 0.15, green: 0.68, blue: 0.38)
        case .mosquito: return Color(red: 0.58, green: 0.64, blue: 0.65)
        case .ladybug: return Color(red: 0.91, green: 0.30, blue: 0.24)
        case .pillbug: return Color(red: 0.09, green: 0.63, blue: 0.52)
        }
    }

    /// SF Symbol used on the emblem; falls back to the bug letter if the symbol
    /// is missing on the running OS.
    static func symbol(_ bug: Bug) -> String {
        switch bug {
        case .queen: return "crown.fill"
        case .ant: return "ant.fill"
        case .spider: return "tortoise.fill"
        case .beetle: return "ladybug.fill"
        case .grasshopper: return "hare.fill"
        case .mosquito: return "drop.fill"
        case .ladybug: return "ladybug.fill"
        case .pillbug: return "pills.fill"
        }
    }
}
