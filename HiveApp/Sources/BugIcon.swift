import SwiftUI
import HiveEngine

/// A small hand-drawn glyph for each bug, filled as a single even-odd silhouette
/// (so a spot or seam that lies fully inside a body shape becomes a cut-out
/// showing the background through, rather than invisible white-on-white).
/// Deliberately bold with few sub-paths — icons render as small as ~12pt in the
/// hand tray, so fine detail would just turn to mud. See CLAUDE.md → "Tiles are
/// labelled by name, not icon or initial" for why there's no single mixed-style
/// SF Symbol set: no stock symbol exists for half these bugs, so all eight share
/// one drawn style instead of mixing systems.
struct BugIcon: View {
    let bug: Bug

    var body: some View {
        GlyphShape(bug: bug)
            .fill(style: FillStyle(eoFill: true))
    }
}

private struct GlyphShape: Shape {
    let bug: Bug

    func path(in rect: CGRect) -> Path {
        switch bug {
        case .queen: return BugGlyphs.queen(rect)
        case .beetle: return BugGlyphs.beetle(rect)
        case .grasshopper: return BugGlyphs.grasshopper(rect)
        case .spider: return BugGlyphs.spider(rect)
        case .ant: return BugGlyphs.ant(rect)
        case .mosquito: return BugGlyphs.mosquito(rect)
        case .ladybug: return BugGlyphs.ladybug(rect)
        case .pillbug: return BugGlyphs.pillbug(rect)
        }
    }
}

private extension CGRect {
    /// A point at fraction (x, y) of this rect, each in 0...1.
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: minX + width * x, y: minY + height * y) }
    /// A length as a fraction of the shorter side.
    func len(_ f: CGFloat) -> CGFloat { min(width, height) * f }
}

private extension Path {
    mutating func addOval(_ rect: CGRect, center: CGPoint, rx: CGFloat, ry: CGFloat) {
        addEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    }
    mutating func addDot(_ center: CGPoint, r: CGFloat) {
        addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }
    /// A filled straight segment of a given width — reads as a bold limb/line at
    /// tiny sizes without a separate stroke pass.
    mutating func addLimb(from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len * width / 2, ny = dx / len * width / 2
        move(to: CGPoint(x: a.x + nx, y: a.y + ny))
        addLine(to: CGPoint(x: b.x + nx, y: b.y + ny))
        addLine(to: CGPoint(x: b.x - nx, y: b.y - ny))
        addLine(to: CGPoint(x: a.x - nx, y: a.y - ny))
        closeSubpath()
    }
}

/// The eight glyph paths, each authored in a normalized 0...1 box via `rect.pt`.
private enum BugGlyphs {
    static func queen(_ r: CGRect) -> Path {
        var p = Path()
        p.addOval(r, center: r.pt(0.5, 0.64), rx: r.len(0.20), ry: r.len(0.24))       // body
        p.addDot(r.pt(0.5, 0.34), r: r.len(0.10))                                    // head
        p.addOval(r, center: r.pt(0.28, 0.48), rx: r.len(0.15), ry: r.len(0.08))      // left wing
        p.addOval(r, center: r.pt(0.72, 0.48), rx: r.len(0.15), ry: r.len(0.08))      // right wing
        // Crown, resting above the head.
        p.move(to: r.pt(0.30, 0.16))
        p.addLine(to: r.pt(0.34, 0.02))
        p.addLine(to: r.pt(0.42, 0.13))
        p.addLine(to: r.pt(0.50, 0.00))
        p.addLine(to: r.pt(0.58, 0.13))
        p.addLine(to: r.pt(0.66, 0.02))
        p.addLine(to: r.pt(0.70, 0.16))
        p.closeSubpath()
        return p
    }

    static func beetle(_ r: CGRect) -> Path {
        var p = Path()
        p.addOval(r, center: r.pt(0.5, 0.58), rx: r.len(0.32), ry: r.len(0.30))       // shell
        p.addDot(r.pt(0.5, 0.22), r: r.len(0.10))                                    // head
        p.addLimb(from: r.pt(0.5, 0.30), to: r.pt(0.5, 0.84), width: r.len(0.025))    // seam (cut-out)
        for y in [0.40, 0.58, 0.76] {
            p.addLimb(from: r.pt(0.22, y), to: r.pt(0.04, y - 0.04), width: r.len(0.045))
            p.addLimb(from: r.pt(0.78, y), to: r.pt(0.96, y - 0.04), width: r.len(0.045))
        }
        return p
    }

    static func grasshopper(_ r: CGRect) -> Path {
        var p = Path()
        p.addOval(r, center: r.pt(0.48, 0.52), rx: r.len(0.32), ry: r.len(0.15))      // body
        p.addDot(r.pt(0.16, 0.46), r: r.len(0.09))                                   // head
        p.addLimb(from: r.pt(0.10, 0.36), to: r.pt(0.00, 0.16), width: r.len(0.02))   // antenna
        p.addLimb(from: r.pt(0.14, 0.40), to: r.pt(0.06, 0.24), width: r.len(0.02))   // antenna
        p.addLimb(from: r.pt(0.50, 0.60), to: r.pt(0.44, 0.90), width: r.len(0.035))  // front leg
        p.addLimb(from: r.pt(0.68, 0.56), to: r.pt(0.86, 0.34), width: r.len(0.05))   // rear leg: thigh
        p.addLimb(from: r.pt(0.86, 0.34), to: r.pt(0.64, 0.16), width: r.len(0.04))   // rear leg: shin
        return p
    }

    static func spider(_ r: CGRect) -> Path {
        var p = Path()
        p.addDot(r.pt(0.5, 0.5), r: r.len(0.16))                                     // body
        let ys: [CGFloat] = [0.20, 0.36, 0.64, 0.80]
        for y in ys {
            p.addLimb(from: r.pt(0.5, 0.5), to: r.pt(0.02, y), width: r.len(0.03))
            p.addLimb(from: r.pt(0.5, 0.5), to: r.pt(0.98, y), width: r.len(0.03))
        }
        return p
    }

    static func ant(_ r: CGRect) -> Path {
        var p = Path()
        p.addDot(r.pt(0.5, 0.24), r: r.len(0.10))                                    // head
        p.addDot(r.pt(0.5, 0.44), r: r.len(0.09))                                    // thorax
        p.addOval(r, center: r.pt(0.5, 0.70), rx: r.len(0.17), ry: r.len(0.20))       // abdomen
        p.addLimb(from: r.pt(0.5, 0.16), to: r.pt(0.38, 0.02), width: r.len(0.025))   // antenna
        p.addLimb(from: r.pt(0.5, 0.16), to: r.pt(0.62, 0.02), width: r.len(0.025))   // antenna
        for (dx, dy) in [(0.18, 0.32), (0.14, 0.46), (0.20, 0.62)] {
            p.addLimb(from: r.pt(0.5, 0.44), to: r.pt(dx, dy), width: r.len(0.035))
            p.addLimb(from: r.pt(0.5, 0.44), to: r.pt(1 - dx, dy), width: r.len(0.035))
        }
        return p
    }

    static func mosquito(_ r: CGRect) -> Path {
        var p = Path()
        p.addOval(r, center: r.pt(0.52, 0.56), rx: r.len(0.13), ry: r.len(0.24))      // body
        p.addDot(r.pt(0.52, 0.28), r: r.len(0.06))                                   // head
        p.addLimb(from: r.pt(0.52, 0.22), to: r.pt(0.80, 0.02), width: r.len(0.018)) // proboscis
        p.addOval(r, center: r.pt(0.30, 0.42), rx: r.len(0.16), ry: r.len(0.07))      // left wing
        p.addOval(r, center: r.pt(0.74, 0.42), rx: r.len(0.16), ry: r.len(0.07))      // right wing
        for (dx, dy) in [(0.30, 0.70), (0.20, 0.86)] {
            p.addLimb(from: r.pt(0.52, 0.62), to: r.pt(dx, dy), width: r.len(0.02))
            p.addLimb(from: r.pt(0.52, 0.62), to: r.pt(1.04 - dx, dy), width: r.len(0.02))
        }
        return p
    }

    static func ladybug(_ r: CGRect) -> Path {
        var p = Path()
        p.addDot(r.pt(0.5, 0.58), r: r.len(0.32))                                    // shell
        p.addDot(r.pt(0.5, 0.24), r: r.len(0.10))                                    // head
        p.addLimb(from: r.pt(0.5, 0.30), to: r.pt(0.5, 0.86), width: r.len(0.025))    // seam (cut-out)
        for (x, y, dr) in [(0.32, 0.48, 0.055), (0.68, 0.48, 0.055),
                           (0.36, 0.72, 0.05), (0.64, 0.72, 0.05)] {
            p.addDot(r.pt(x, y), r: r.len(dr))                                      // spots (cut-out)
        }
        return p
    }

    static func pillbug(_ r: CGRect) -> Path {
        var p = Path()
        p.addOval(r, center: r.pt(0.54, 0.5), rx: r.len(0.36), ry: r.len(0.26))       // rolled body
        p.addDot(r.pt(0.16, 0.5), r: r.len(0.09))                                    // tucked head
        for x in [0.36, 0.52, 0.68] {
            p.addLimb(from: r.pt(x, 0.24), to: r.pt(x, 0.76), width: r.len(0.028))    // segment lines (cut-out)
        }
        return p
    }
}
