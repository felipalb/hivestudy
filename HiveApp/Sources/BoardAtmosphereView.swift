import SwiftUI
import HiveEngine

/// An ambient natural atmosphere layer for the Hive game board.
///
/// Features:
/// - Organic garden/zen backdrop with subtle forest-green and warm wood tones.
/// - Soft dappled sunlight / ambient canopy illumination.
/// - Gracefully floating ambient golden fireflies and botanical particles.
struct BoardAtmosphereView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Deep organic garden tones
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.08),
                    Color(red: 0.04, green: 0.06, blue: 0.05),
                    Color(red: 0.03, green: 0.04, blue: 0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Dappled sunlight canopy glow at the top center
            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.08),
                    Color(red: 0.35, green: 0.65, blue: 0.45).opacity(0.04),
                    Color.clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 550
            )
            .ignoresSafeArea()

            // Floating garden particles (fireflies and subtle botanical motes)
            if !reduceMotion {
                ambientGardenParticles
                    .ignoresSafeArea()
            }
        }
    }

    private var ambientGardenParticles: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // 8 floating firefly / botanical motes
                for i in 0..<8 {
                    let fi = Double(i)
                    let speed = 0.15 + (fi * 0.02)
                    let angle = fi * (.pi / 4.0) + (t * speed)
                    let radiusX = size.width * 0.42 + CGFloat(sin(t * 0.8 + fi * 1.5)) * 40
                    let radiusY = size.height * 0.42 + CGFloat(cos(t * 0.6 + fi * 1.2)) * 50

                    let x = center.x + cos(angle) * radiusX
                    let y = center.y + sin(angle * 0.7) * radiusY

                    let pulse = 0.35 + sin(t * 1.8 + fi) * 0.30
                    let pSize: CGFloat = (i % 2 == 0) ? 3.0 : 4.5

                    // Warm gold or fresh leaf green color
                    let pColor = (i % 3 == 0)
                        ? Color(red: 0.95, green: 0.82, blue: 0.40)
                        : Color(red: 0.55, green: 0.85, blue: 0.50)

                    context.opacity = pulse
                    context.fill(
                        Circle().path(in: CGRect(x: x - pSize / 2, y: y - pSize / 2, width: pSize, height: pSize)),
                        with: .color(pColor)
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
