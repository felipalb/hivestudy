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

/// The eight animal glyph paths, each authored in a normalized 0...1 box via `rect.pt`.
private enum BugGlyphs {
    /// 🦁 Leão (formerly Queen Bee): Lion head with a majestic radiating mane and crown silhouette.
    static func queen(_ r: CGRect) -> Path {
        var p = Path()
        // Outer mane spikes
        p.addOval(r, center: r.pt(0.5, 0.50), rx: r.len(0.38), ry: r.len(0.38))
        // Ears
        p.addDot(r.pt(0.24, 0.22), r: r.len(0.09))
        p.addDot(r.pt(0.76, 0.22), r: r.len(0.09))
        // Face cutout / inner head
        p.addOval(r, center: r.pt(0.5, 0.52), rx: r.len(0.24), ry: r.len(0.25))
        // Snout and nose
        p.addDot(r.pt(0.5, 0.58), r: r.len(0.08))
        // Mane details (cut-outs)
        for angle in stride(from: 0.0, to: 2.0 * .pi, by: .pi / 4.0) {
            let cx = 0.5 + 0.32 * cos(angle)
            let cy = 0.5 + 0.32 * sin(angle)
            p.addDot(r.pt(cx, cy), r: r.len(0.04))
        }
        return p
    }

    /// 🦍 Gorila (formerly Beetle): Broad, powerful shoulders, muscular chest and strong head.
    static func beetle(_ r: CGRect) -> Path {
        var p = Path()
        // Head with prominent brow
        p.addDot(r.pt(0.5, 0.22), r: r.len(0.14))
        // Heavy muscular torso
        p.addOval(r, center: r.pt(0.5, 0.60), rx: r.len(0.38), ry: r.len(0.30))
        // Broad shoulders
        p.addDot(r.pt(0.18, 0.44), r: r.len(0.12))
        p.addDot(r.pt(0.82, 0.44), r: r.len(0.12))
        // Grounded arms
        p.addLimb(from: r.pt(0.18, 0.44), to: r.pt(0.14, 0.84), width: r.len(0.10))
        p.addLimb(from: r.pt(0.82, 0.44), to: r.pt(0.86, 0.84), width: r.len(0.10))
        // Chest definition cut-outs
        p.addDot(r.pt(0.40, 0.52), r: r.len(0.06))
        p.addDot(r.pt(0.60, 0.52), r: r.len(0.06))
        return p
    }

    /// 🦘 Canguru (formerly Grasshopper): Kangaroo in iconic leaping silhouette with long tail and upright ears.
    static func grasshopper(_ r: CGRect) -> Path {
        var p = Path()
        // Head
        p.addDot(r.pt(0.68, 0.24), r: r.len(0.11))
        // Long alert ears
        p.addLimb(from: r.pt(0.66, 0.20), to: r.pt(0.62, 0.04), width: r.len(0.035))
        p.addLimb(from: r.pt(0.72, 0.20), to: r.pt(0.72, 0.04), width: r.len(0.035))
        // Slender neck & torso
        p.addOval(r, center: r.pt(0.50, 0.46), rx: r.len(0.22), ry: r.len(0.18))
        // Powerful leaping hind thigh & leg
        p.addOval(r, center: r.pt(0.34, 0.64), rx: r.len(0.20), ry: r.len(0.14))
        p.addLimb(from: r.pt(0.32, 0.70), to: r.pt(0.48, 0.94), width: r.len(0.07))
        // Long sweeping counterbalancing tail
        p.addLimb(from: r.pt(0.24, 0.56), to: r.pt(0.04, 0.78), width: r.len(0.065))
        // Forearms held forward
        p.addLimb(from: r.pt(0.58, 0.46), to: r.pt(0.74, 0.54), width: r.len(0.04))
        return p
    }

    /// 🦓 Zebra (formerly Spider): Proud zebra head in profile with distinct cut-out stripes.
    static func spider(_ r: CGRect) -> Path {
        var p = Path()
        // Head & Muzzle
        p.addOval(r, center: r.pt(0.58, 0.54), rx: r.len(0.26), ry: r.len(0.16))
        p.addDot(r.pt(0.80, 0.60), r: r.len(0.10)) // muzzle
        // Neck & Crest
        p.addOval(r, center: r.pt(0.36, 0.58), rx: r.len(0.22), ry: r.len(0.28))
        // Ears
        p.addLimb(from: r.pt(0.38, 0.32), to: r.pt(0.34, 0.10), width: r.len(0.05))
        p.addLimb(from: r.pt(0.44, 0.32), to: r.pt(0.46, 0.12), width: r.len(0.045))
        // Distinctive Zebra vertical stripes (cut-outs)
        for x in [0.28, 0.38, 0.48, 0.58, 0.68] {
            p.addLimb(from: r.pt(x, 0.36), to: r.pt(x - 0.04, 0.76), width: r.len(0.035))
        }
        return p
    }

    /// 🐆 Guepardo (formerly Ant Soldado): Streamlined, athletic running feline silhouette.
    static func ant(_ r: CGRect) -> Path {
        var p = Path()
        // Aerodynamic arched body
        p.addOval(r, center: r.pt(0.50, 0.50), rx: r.len(0.36), ry: r.len(0.15))
        // Sleek head & small ears
        p.addDot(r.pt(0.82, 0.40), r: r.len(0.11))
        p.addDot(r.pt(0.80, 0.28), r: r.len(0.04))
        // Front sprint legs
        p.addLimb(from: r.pt(0.70, 0.54), to: r.pt(0.88, 0.82), width: r.len(0.05))
        // Hind spring legs
        p.addLimb(from: r.pt(0.30, 0.54), to: r.pt(0.14, 0.84), width: r.len(0.06))
        // Long dynamic curved tail
        p.addLimb(from: r.pt(0.20, 0.46), to: r.pt(0.04, 0.26), width: r.len(0.045))
        p.addLimb(from: r.pt(0.04, 0.26), to: r.pt(0.14, 0.16), width: r.len(0.04))
        // Coat spot cut-outs
        p.addDot(r.pt(0.42, 0.48), r: r.len(0.035))
        p.addDot(r.pt(0.56, 0.46), r: r.len(0.035))
        p.addDot(r.pt(0.48, 0.54), r: r.len(0.035))
        return p
    }

    /// 🦎 Camaleão (formerly Mosquito): Chameleon with curled spiral tail, eye turret, and crest.
    static func mosquito(_ r: CGRect) -> Path {
        var p = Path()
        // Arched body
        p.addOval(r, center: r.pt(0.50, 0.46), rx: r.len(0.26), ry: r.len(0.22))
        // Head with helmet crest
        p.addDot(r.pt(0.74, 0.38), r: r.len(0.13))
        p.addLimb(from: r.pt(0.68, 0.30), to: r.pt(0.60, 0.16), width: r.len(0.05))
        // Big round eye cutout
        p.addDot(r.pt(0.74, 0.36), r: r.len(0.045))
        // Coiled spiral tail
        p.addOval(r, center: r.pt(0.22, 0.62), rx: r.len(0.14), ry: r.len(0.14))
        p.addLimb(from: r.pt(0.34, 0.52), to: r.pt(0.22, 0.62), width: r.len(0.05))
        p.addDot(r.pt(0.22, 0.62), r: r.len(0.05)) // inner coil cutout
        // Climbing feet
        p.addLimb(from: r.pt(0.62, 0.60), to: r.pt(0.68, 0.86), width: r.len(0.045))
        p.addLimb(from: r.pt(0.42, 0.60), to: r.pt(0.38, 0.86), width: r.len(0.045))
        return p
    }

    /// 🦅 Águia (formerly Ladybug): Soaring eagle with wide outstretched wings and sharp beak.
    static func ladybug(_ r: CGRect) -> Path {
        var p = Path()
        // Eagle body and tail
        p.addOval(r, center: r.pt(0.50, 0.52), rx: r.len(0.13), ry: r.len(0.26))
        p.addLimb(from: r.pt(0.50, 0.70), to: r.pt(0.50, 0.94), width: r.len(0.10)) // fan tail
        // Head & hooked beak
        p.addDot(r.pt(0.50, 0.22), r: r.len(0.09))
        p.addLimb(from: r.pt(0.50, 0.22), to: r.pt(0.64, 0.20), width: r.len(0.035)) // beak
        // Left soaring wing
        p.move(to: r.pt(0.44, 0.44))
        p.addLine(to: r.pt(0.04, 0.22))
        p.addLine(to: r.pt(0.12, 0.46))
        p.addLine(to: r.pt(0.44, 0.56))
        p.closeSubpath()
        // Right soaring wing
        p.move(to: r.pt(0.56, 0.44))
        p.addLine(to: r.pt(0.96, 0.22))
        p.addLine(to: r.pt(0.88, 0.46))
        p.addLine(to: r.pt(0.56, 0.56))
        p.closeSubpath()
        return p
    }

    /// 🛡️ Tatu-bola (formerly Pillbug): Armadillo with arched armored protective plates.
    static func pillbug(_ r: CGRect) -> Path {
        var p = Path()
        p.addOval(r, center: r.pt(0.54, 0.50), rx: r.len(0.36), ry: r.len(0.26))       // rolled shell
        p.addDot(r.pt(0.16, 0.50), r: r.len(0.09))                                    // head
        for x in [0.36, 0.52, 0.68] {
            p.addLimb(from: r.pt(x, 0.24), to: r.pt(x, 0.76), width: r.len(0.028))    // shell band cut-outs
        }
        return p
    }
}
