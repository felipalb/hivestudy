import SwiftUI
import HiveEngine

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }
}

/// Converts between axial hex coordinates and screen points for a pointy-top
/// hexagonal grid. `size` is the hex radius (centre to a corner).
struct HexLayout {
    var size: CGFloat

    /// A tile's dimensions for a pointy-top hexagon of this radius.
    var tileWidth: CGFloat { size * sqrt(3) }
    var tileHeight: CGFloat { size * 2 }

    func point(for hex: Hex) -> CGPoint {
        let x = size * (sqrt(3) * CGFloat(hex.q) + sqrt(3) / 2 * CGFloat(hex.r))
        let y = size * (3.0 / 2.0 * CGFloat(hex.r))
        return CGPoint(x: x, y: y)
    }

    func hex(for point: CGPoint) -> Hex {
        let q = (sqrt(3) / 3 * point.x - 1.0 / 3 * point.y) / size
        let r = (2.0 / 3 * point.y) / size
        return HexLayout.roundToHex(q: Double(q), r: Double(r))
    }

    /// Cube-rounding of fractional axial coordinates to the nearest hex.
    static func roundToHex(q: Double, r: Double) -> Hex {
        let s = -q - r
        var rq = q.rounded()
        var rr = r.rounded()
        let rs = s.rounded()
        let dq = abs(rq - q), dr = abs(rr - r), ds = abs(rs - s)
        if dq > dr && dq > ds {
            rq = -rr - rs
        } else if dr > ds {
            rr = -rq - rs
        }
        return Hex(Int(rq), Int(rr))
    }
}

/// A pointy-top regular hexagon that fills its frame.
struct RegularHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width / sqrt(3), rect.height / 2)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2   // vertex at top
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
