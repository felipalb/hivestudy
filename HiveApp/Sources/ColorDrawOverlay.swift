import SwiftUI
import HiveEngine

/// A 3D coin-toss / tile-flip animation overlay that reveals whether the player
/// was randomly assigned White (plays first) or Black (opponent plays first).
///
/// Features a large 3D hexagonal tile spinning around its Y-axis with realistic
/// deceleration, dynamic haptic ticks during rotation, an explosive landing shockwave,
/// and a celebratory result card.
struct ColorDrawOverlay: View {
    let drawnColor: PlayerColor
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rotationY: Double = 0
    @State private var tileScale: CGFloat = 0.5
    @State private var tileOpacity: Double = 0
    @State private var isRevealed: Bool = false
    @State private var showResultCard: Bool = false
    @State private var shockwaveScale: CGFloat = 0.6
    @State private var shockwaveOpacity: Double = 0
    @State private var ambientGlowOpacity: Double = 0
    @State private var autoDismissTask: Task<Void, Never>?

    private let hexSize: CGFloat = 52
    private var layout: HexLayout { HexLayout(size: hexSize) }

    /// Total target rotation angle: 5 full spins (1800°) for White, 5.5 spins (1980°) for Black.
    private var targetAngle: Double {
        drawnColor == .white ? 1800 : 1980
    }

    /// Determines which face of the tile is currently visible during the 3D rotation.
    private var currentFaceColor: PlayerColor {
        let normalized = Int(rotationY.truncatingRemainder(dividingBy: 360) + 360) % 360
        return (normalized >= 90 && normalized < 270) ? .black : .white
    }

    /// Whether the text/emblem should be mirrored so it reads normally when viewing the back face.
    private var isBackFace: Bool {
        let normalized = Int(rotationY.truncatingRemainder(dividingBy: 360) + 360) % 360
        return normalized >= 90 && normalized < 270
    }

    var body: some View {
        ZStack {
            // Dark frosted background scrim
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    if isRevealed { finish() }
                }

            // Ambient background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (drawnColor == .white ? HiveTheme.selection : Color("HiveAccentQueen")).opacity(ambientGlowOpacity),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .allowsHitTesting(false)

            // Expanding shockwave on reveal
            RegularHexagon()
                .stroke(
                    drawnColor == .white ? HiveTheme.selection : Color("HiveAccentQueen"),
                    lineWidth: 3
                )
                .frame(width: layout.tileWidth, height: layout.tileHeight)
                .scaleEffect(shockwaveScale)
                .opacity(shockwaveOpacity)
                .allowsHitTesting(false)

            VStack(spacing: 28) {
                // Header badge
                headerBadge
                    .opacity(tileOpacity)

                // The 3D Spinning Hexagon Tile
                spinningTile
                    .frame(width: layout.tileWidth, height: layout.tileHeight)
                    .scaleEffect(tileScale)
                    .opacity(tileOpacity)
                    .rotation3DEffect(
                        .degrees(rotationY),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.75
                    )
                    .shadow(
                        color: (isRevealed ? (drawnColor == .white ? HiveTheme.selection : Color("HiveAccentQueen")) : .black).opacity(0.6),
                        radius: isRevealed ? 24 : 14,
                        y: isRevealed ? 8 : 4
                    )

                // Result card and play button
                if showResultCard {
                    resultCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(24)
            .frame(maxWidth: 380)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    // MARK: - Subviews

    private var headerBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "dice.fill")
                .font(.system(size: 14, weight: .bold))
            Text("SORTEIO DE CORES")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1.2)
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var spinningTile: some View {
        let faceColor = currentFaceColor
        let imageName = faceColor == .white ? "PieceLionWhite" : "PieceLionBlack"
        let borderColor = faceColor == .white
            ? Color(red: 0.95, green: 0.85, blue: 0.60).opacity(0.85)
            : Color(red: 1.0, green: 0.70, blue: 0.20).opacity(0.85)

        return ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: layout.tileWidth, height: layout.tileHeight)
                .clipShape(RegularHexagon())
                // Un-mirror when viewing back face in 3D rotation
                .scaleEffect(x: isBackFace ? -1 : 1, y: 1)
                .overlay(
                    RegularHexagon()
                        .stroke(
                            isRevealed ? HiveTheme.selection : borderColor,
                            lineWidth: isRevealed ? hexSize * 0.12 : max(1.5, hexSize * 0.06)
                        )
                )
        }
        .contentShape(RegularHexagon())
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(drawnColor == .white ? "Você joga de Brancas!" : "Você joga de Pretas!")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(drawnColor == .white ? "Você faz o primeiro movimento." : "O computador inicia a partida.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: finish) {
                HStack(spacing: 8) {
                    Text("Começar Partida")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HiveTheme.selection)
                )
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        if reduceMotion {
            rotationY = targetAngle
            tileScale = 1.0
            tileOpacity = 1.0
            isRevealed = true
            showResultCard = true
            ambientGlowOpacity = 0.35
            Haptics.success()
            return
        }

        // Entrance
        withAnimation(.easeOut(duration: 0.35)) {
            tileOpacity = 1.0
            tileScale = 1.0
        }

        // 3D Spin with realistic deceleration
        withAnimation(.timingCurve(0.12, 0.8, 0.25, 1.0, duration: 1.6)) {
            rotationY = targetAngle
        }

        // Haptic feedback pulses during rotation
        scheduleHapticTicks()

        // Reveal landing after rotation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            triggerLandingEffects()
        }
    }

    private func scheduleHapticTicks() {
        let tickIntervals: [Double] = [0.08, 0.18, 0.30, 0.44, 0.60, 0.80, 1.05, 1.35]
        for interval in tickIntervals {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                Haptics.light()
            }
        }
    }

    private func triggerLandingEffects() {
        isRevealed = true
        Haptics.success()

        // Bounce effect
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            tileScale = 1.12
            ambientGlowOpacity = 0.4
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
            tileScale = 1.0
        }

        // Shockwave expansion
        shockwaveOpacity = 0.8
        shockwaveScale = 0.8
        withAnimation(.easeOut(duration: 0.7)) {
            shockwaveScale = 2.2
            shockwaveOpacity = 0
        }

        // Reveal card
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
            showResultCard = true
        }

        // Auto dismiss after 2.8 seconds of being revealed
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            await MainActor.run { finish() }
        }
    }

    private func finish() {
        autoDismissTask?.cancel()
        Haptics.selection()
        withAnimation(.easeOut(duration: 0.25)) {
            tileOpacity = 0
            showResultCard = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onComplete()
        }
    }
}
