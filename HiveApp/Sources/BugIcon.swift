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

/// The eight animal glyph paths, each authored with smooth curves and distinctive geometric silhouettes.
private enum BugGlyphs {
    /// 🦁 Leão (Lion): Regal lion emblem with stylized radiant mane, ears, and facial features.
    static func queen(_ r: CGRect) -> Path {
        var p = Path()
        // Outer Crown & Majestic Mane Silhouette
        p.move(to: r.pt(0.50, 0.02))
        p.addLine(to: r.pt(0.58, 0.12))
        p.addLine(to: r.pt(0.70, 0.05))
        p.addLine(to: r.pt(0.76, 0.18))
        p.addLine(to: r.pt(0.90, 0.18))
        p.addQuadCurve(to: r.pt(0.94, 0.44), control: r.pt(0.98, 0.30))
        p.addQuadCurve(to: r.pt(0.82, 0.72), control: r.pt(0.94, 0.62))
        p.addQuadCurve(to: r.pt(0.50, 0.98), control: r.pt(0.70, 0.95))
        p.addQuadCurve(to: r.pt(0.18, 0.72), control: r.pt(0.30, 0.95))
        p.addQuadCurve(to: r.pt(0.06, 0.44), control: r.pt(0.06, 0.62))
        p.addQuadCurve(to: r.pt(0.10, 0.18), control: r.pt(0.02, 0.30))
        p.addLine(to: r.pt(0.24, 0.18))
        p.addLine(to: r.pt(0.30, 0.05))
        p.addLine(to: r.pt(0.42, 0.12))
        p.closeSubpath()

        // Inner Face Mask (Cut-out)
        p.move(to: r.pt(0.50, 0.22))
        p.addQuadCurve(to: r.pt(0.74, 0.42), control: r.pt(0.68, 0.24))
        p.addQuadCurve(to: r.pt(0.68, 0.68), control: r.pt(0.74, 0.58))
        p.addLine(to: r.pt(0.50, 0.86))
        p.addLine(to: r.pt(0.32, 0.68))
        p.addQuadCurve(to: r.pt(0.26, 0.42), control: r.pt(0.26, 0.58))
        p.addQuadCurve(to: r.pt(0.50, 0.22), control: r.pt(0.32, 0.24))
        p.closeSubpath()

        // Almond Eyes & Nose (Solid core details)
        p.addOval(r, center: r.pt(0.40, 0.46), rx: r.len(0.05), ry: r.len(0.035))
        p.addOval(r, center: r.pt(0.60, 0.46), rx: r.len(0.05), ry: r.len(0.035))
        p.addDot(r.pt(0.50, 0.64), r: r.len(0.06))
        return p
    }

    /// 🦍 Gorila (Gorilla): Powerful Silverback bust with sagittal crest, heavy brow, and massive shoulders.
    static func beetle(_ r: CGRect) -> Path {
        var p = Path()
        // Massive Silverback Body & Shoulder Silhouette
        p.move(to: r.pt(0.50, 0.06)) // Sagittal Crest
        p.addQuadCurve(to: r.pt(0.70, 0.18), control: r.pt(0.64, 0.08))
        p.addQuadCurve(to: r.pt(0.94, 0.42), control: r.pt(0.86, 0.26))
        p.addQuadCurve(to: r.pt(0.88, 0.88), control: r.pt(0.96, 0.70))
        p.addLine(to: r.pt(0.74, 0.94))
        p.addQuadCurve(to: r.pt(0.50, 0.78), control: r.pt(0.62, 0.90))
        p.addQuadCurve(to: r.pt(0.26, 0.94), control: r.pt(0.38, 0.90))
        p.addLine(to: r.pt(0.12, 0.88))
        p.addQuadCurve(to: r.pt(0.06, 0.42), control: r.pt(0.04, 0.70))
        p.addQuadCurve(to: r.pt(0.30, 0.18), control: r.pt(0.14, 0.26))
        p.addQuadCurve(to: r.pt(0.50, 0.06), control: r.pt(0.36, 0.08))
        p.closeSubpath()

        // Heavy Brow & Face Cut-out
        p.move(to: r.pt(0.32, 0.32))
        p.addLine(to: r.pt(0.68, 0.32))
        p.addQuadCurve(to: r.pt(0.64, 0.62), control: r.pt(0.70, 0.48))
        p.addQuadCurve(to: r.pt(0.50, 0.70), control: r.pt(0.58, 0.68))
        p.addQuadCurve(to: r.pt(0.36, 0.62), control: r.pt(0.42, 0.68))
        p.addQuadCurve(to: r.pt(0.32, 0.32), control: r.pt(0.30, 0.48))
        p.closeSubpath()

        // Piercing Eyes & Broad Nostrils (Solid features inside face)
        p.addDot(r.pt(0.42, 0.42), r: r.len(0.035))
        p.addDot(r.pt(0.58, 0.42), r: r.len(0.035))
        p.addOval(r, center: r.pt(0.46, 0.54), rx: r.len(0.03), ry: r.len(0.04))
        p.addOval(r, center: r.pt(0.54, 0.54), rx: r.len(0.03), ry: r.len(0.04))
        return p
    }

    /// 🦘 Canguru (Kangaroo): Dynamic leaping kangaroo silhouette with long ears, spring legs, and counterweight tail.
    static func grasshopper(_ r: CGRect) -> Path {
        var p = Path()
        // Kangaroo Silhouette in Leaping Motion
        p.move(to: r.pt(0.68, 0.02)) // Ear tips
        p.addLine(to: r.pt(0.64, 0.18))
        p.addQuadCurve(to: r.pt(0.86, 0.28), control: r.pt(0.76, 0.20)) // Snout
        p.addQuadCurve(to: r.pt(0.72, 0.40), control: r.pt(0.82, 0.38)) // Chin/Throat
        p.addQuadCurve(to: r.pt(0.80, 0.52), control: r.pt(0.78, 0.46)) // Forepaws
        p.addLine(to: r.pt(0.68, 0.56))
        p.addQuadCurve(to: r.pt(0.58, 0.88), control: r.pt(0.64, 0.72)) // Powerful hind leg & foot
        p.addLine(to: r.pt(0.44, 0.94))
        p.addQuadCurve(to: r.pt(0.34, 0.68), control: r.pt(0.48, 0.80)) // Thigh
        p.addQuadCurve(to: r.pt(0.04, 0.84), control: r.pt(0.18, 0.66)) // Long arched tail
        p.addQuadCurve(to: r.pt(0.24, 0.50), control: r.pt(0.12, 0.60)) // Back curve
        p.addQuadCurve(to: r.pt(0.54, 0.24), control: r.pt(0.38, 0.34)) // Neck
        p.addLine(to: r.pt(0.60, 0.04))
        p.closeSubpath()

        // Pouch / Inner line accent (Cut-out)
        p.addOval(r, center: r.pt(0.52, 0.52), rx: r.len(0.06), ry: r.len(0.09))
        // Eye Dot
        p.addDot(r.pt(0.74, 0.25), r: r.len(0.028))
        return p
    }

    /// 🦓 Zebra: Proud wild zebra in profile with crisp, elegant geometric stripes.
    static func spider(_ r: CGRect) -> Path {
        var p = Path()
        // Zebra Head & Neck Profile
        p.move(to: r.pt(0.34, 0.04)) // Upright Mane top
        p.addLine(to: r.pt(0.44, 0.04))
        p.addQuadCurve(to: r.pt(0.88, 0.56), control: r.pt(0.68, 0.20)) // Muzzle top
        p.addQuadCurve(to: r.pt(0.78, 0.72), control: r.pt(0.88, 0.68)) // Muzzle bottom
        p.addQuadCurve(to: r.pt(0.54, 0.60), control: r.pt(0.66, 0.72)) // Jawline
        p.addQuadCurve(to: r.pt(0.44, 0.96), control: r.pt(0.50, 0.82)) // Throat/Chest
        p.addLine(to: r.pt(0.18, 0.94))
        p.addQuadCurve(to: r.pt(0.24, 0.40), control: r.pt(0.16, 0.64)) // Back of neck
        p.addLine(to: r.pt(0.34, 0.04))
        p.closeSubpath()

        // Elegant Zebra Stripe Cut-outs
        p.addLimb(from: r.pt(0.28, 0.22), to: r.pt(0.50, 0.44), width: r.len(0.045))
        p.addLimb(from: r.pt(0.24, 0.42), to: r.pt(0.48, 0.62), width: r.len(0.045))
        p.addLimb(from: r.pt(0.22, 0.64), to: r.pt(0.42, 0.82), width: r.len(0.045))
        p.addLimb(from: r.pt(0.54, 0.28), to: r.pt(0.68, 0.42), width: r.len(0.04))
        p.addDot(r.pt(0.76, 0.60), r: r.len(0.04)) // Nostril
        return p
    }

    /// 🐆 Guepardo (Cheetah): Aerodynamic running cheetah silhouette with tear stripes and speed posture.
    static func ant(_ r: CGRect) -> Path {
        var p = Path()
        // Sleek Running Cheetah Silhouette
        p.move(to: r.pt(0.82, 0.24)) // Sleek Head
        p.addQuadCurve(to: r.pt(0.96, 0.36), control: r.pt(0.92, 0.26)) // Snout
        p.addQuadCurve(to: r.pt(0.84, 0.46), control: r.pt(0.92, 0.46)) // Chin
        p.addQuadCurve(to: r.pt(0.94, 0.78), control: r.pt(0.96, 0.62)) // Forward Sprint Leg
        p.addLine(to: r.pt(0.84, 0.84))
        p.addQuadCurve(to: r.pt(0.62, 0.54), control: r.pt(0.76, 0.64)) // Underbelly arch
        p.addQuadCurve(to: r.pt(0.44, 0.54), control: r.pt(0.52, 0.58))
        p.addQuadCurve(to: r.pt(0.18, 0.94), control: r.pt(0.36, 0.76)) // Hind Leap Leg
        p.addLine(to: r.pt(0.08, 0.88))
        p.addQuadCurve(to: r.pt(0.24, 0.54), control: r.pt(0.14, 0.68)) // Thigh
        p.addQuadCurve(to: r.pt(0.06, 0.16), control: r.pt(0.12, 0.36)) // Long Curved Balancing Tail
        p.addQuadCurve(to: r.pt(0.20, 0.12), control: r.pt(0.10, 0.10))
        p.addQuadCurve(to: r.pt(0.36, 0.42), control: r.pt(0.22, 0.32)) // Arched Spine
        p.addQuadCurve(to: r.pt(0.72, 0.24), control: r.pt(0.54, 0.34)) // Shoulders & Neck
        p.closeSubpath()

        // Cheetah Rosettes & Tear-mark Cut-outs
        p.addOval(r, center: r.pt(0.48, 0.44), rx: r.len(0.04), ry: r.len(0.03))
        p.addOval(r, center: r.pt(0.62, 0.40), rx: r.len(0.04), ry: r.len(0.03))
        p.addDot(r.pt(0.86, 0.32), r: r.len(0.025)) // Eye
        return p
    }

    /// 🦎 Camaleão (Chameleon): Iconic chameleon with crested casque, spiral Fibonacci tail, and large turret eye.
    static func mosquito(_ r: CGRect) -> Path {
        var p = Path()
        // Arched Casque Body & Tail Spiral Silhouette
        p.move(to: r.pt(0.62, 0.08)) // Crest peak
        p.addQuadCurve(to: r.pt(0.92, 0.32), control: r.pt(0.82, 0.12)) // Snout
        p.addQuadCurve(to: r.pt(0.82, 0.54), control: r.pt(0.92, 0.50)) // Throat
        p.addQuadCurve(to: r.pt(0.76, 0.88), control: r.pt(0.84, 0.74)) // Front Pincer Foot
        p.addLine(to: r.pt(0.66, 0.86))
        p.addQuadCurve(to: r.pt(0.54, 0.62), control: r.pt(0.64, 0.72)) // Belly
        p.addQuadCurve(to: r.pt(0.48, 0.88), control: r.pt(0.54, 0.76)) // Rear Pincer Foot
        p.addLine(to: r.pt(0.38, 0.86))
        p.addQuadCurve(to: r.pt(0.28, 0.62), control: r.pt(0.36, 0.72)) // Tail base
        // Fibonacci Spiral Tail
        p.addQuadCurve(to: r.pt(0.06, 0.60), control: r.pt(0.12, 0.76))
        p.addQuadCurve(to: r.pt(0.20, 0.38), control: r.pt(0.04, 0.44))
        p.addQuadCurve(to: r.pt(0.28, 0.54), control: r.pt(0.26, 0.42))
        p.addQuadCurve(to: r.pt(0.16, 0.58), control: r.pt(0.26, 0.62)) // inner curl
        p.addQuadCurve(to: r.pt(0.34, 0.44), control: r.pt(0.16, 0.48))
        p.addQuadCurve(to: r.pt(0.52, 0.20), control: r.pt(0.40, 0.30)) // High arched back
        p.addLine(to: r.pt(0.62, 0.08))
        p.closeSubpath()

        // Large Turret Eye & Color Bands (Cut-outs)
        p.addOval(r, center: r.pt(0.76, 0.34), rx: r.len(0.07), ry: r.len(0.07))
        p.addDot(r.pt(0.76, 0.34), r: r.len(0.025)) // pupil
        p.addLimb(from: r.pt(0.48, 0.32), to: r.pt(0.44, 0.52), width: r.len(0.035))
        p.addLimb(from: r.pt(0.58, 0.28), to: r.pt(0.56, 0.50), width: r.len(0.035))
        return p
    }

    /// 🦅 Águia (Eagle): Majestic soaring eagle with sharp curved beak, spread wings, and fanned tail.
    static func ladybug(_ r: CGRect) -> Path {
        var p = Path()
        // Eagle Head & Hooked Beak
        p.move(to: r.pt(0.50, 0.08))
        p.addQuadCurve(to: r.pt(0.66, 0.16), control: r.pt(0.60, 0.08)) // Hooked beak tip
        p.addLine(to: r.pt(0.54, 0.24))
        // Right Wing (Spread Feathers)
        p.addLine(to: r.pt(0.82, 0.10))
        p.addLine(to: r.pt(0.76, 0.26))
        p.addLine(to: r.pt(0.96, 0.20))
        p.addLine(to: r.pt(0.86, 0.38))
        p.addLine(to: r.pt(0.98, 0.38))
        p.addQuadCurve(to: r.pt(0.62, 0.60), control: r.pt(0.86, 0.54))
        // Fanned Tail Feathers
        p.addLine(to: r.pt(0.64, 0.94))
        p.addLine(to: r.pt(0.50, 0.86))
        p.addLine(to: r.pt(0.36, 0.94))
        p.addLine(to: r.pt(0.38, 0.60))
        // Left Wing (Spread Feathers)
        p.addQuadCurve(to: r.pt(0.02, 0.38), control: r.pt(0.14, 0.54))
        p.addLine(to: r.pt(0.14, 0.38))
        p.addLine(to: r.pt(0.04, 0.20))
        p.addLine(to: r.pt(0.24, 0.26))
        p.addLine(to: r.pt(0.18, 0.10))
        p.addLine(to: r.pt(0.46, 0.24))
        p.addQuadCurve(to: r.pt(0.50, 0.08), control: r.pt(0.46, 0.14))
        p.closeSubpath()

        // Fierce Eye Cut-out
        p.addDot(r.pt(0.48, 0.18), r: r.len(0.035))
        return p
    }

    /// 🛡️ Tatu-bola (Armadillo): Armadillo with segmented armor plates and protective curl.
    static func pillbug(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: r.pt(0.20, 0.40))
        p.addQuadCurve(to: r.pt(0.50, 0.08), control: r.pt(0.30, 0.10))
        p.addQuadCurve(to: r.pt(0.88, 0.44), control: r.pt(0.78, 0.12))
        p.addQuadCurve(to: r.pt(0.78, 0.88), control: r.pt(0.92, 0.72))
        p.addQuadCurve(to: r.pt(0.30, 0.88), control: r.pt(0.50, 0.96))
        p.addQuadCurve(to: r.pt(0.10, 0.58), control: r.pt(0.18, 0.86))
        p.closeSubpath()

        // Armored Bands (Cut-outs)
        p.addLimb(from: r.pt(0.34, 0.22), to: r.pt(0.38, 0.82), width: r.len(0.04))
        p.addLimb(from: r.pt(0.50, 0.18), to: r.pt(0.52, 0.84), width: r.len(0.04))
        p.addLimb(from: r.pt(0.66, 0.22), to: r.pt(0.66, 0.82), width: r.len(0.04))
        p.addDot(r.pt(0.20, 0.52), r: r.len(0.035))
        return p
    }
}
