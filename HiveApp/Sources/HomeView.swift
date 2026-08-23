import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// The Hero Home screen of Hive.
///
/// Features:
/// - Top-left: Settings & Menu button (`gearshape.fill`).
/// - Center-top: Mesmerizing 3D rotating showcase of all bugs with shifting color accents and ambient lighting.
/// - Title: H I V E branding with elegant typography.
/// - 3 Main Action Buttons:
///   1. "Jogar contra bots" -> triggers 3D coin toss and starts game against AI.
///   2. "Online" -> triggers online mode.
///   3. "Jogar tutorial" -> launches guided interactive tutorial.
struct HomeView: View {
    let onPlayBots: () -> Void
    let onPlayOnline: () -> Void
    let onPlayTutorial: () -> Void
    let onOpenSettings: () -> Void

    @State private var showOnlineToast = false
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Ambient Dark Background with gradient lighting
            backgroundLayer

            VStack(spacing: 0) {
                // Top Bar with Settings
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer(minLength: 4)

                // 3D Hexagon Piece Showcase
                Hero3DShowcase()
                    .frame(height: 220)

                // Branding Title
                titleSection
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                // Action Buttons (3 Clean Buttons)
                actionButtons
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }

            // Online "Em breve" toast notification
            if showOnlineToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HiveTheme.selection)
                        Text("Modo Online em desenvolvimento!")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
                }
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showOnlineToast)
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(.white)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configurações e Menu")

            Spacer()
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text("H U L I")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .tracking(8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(white: 0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .white.opacity(0.2), radius: 12, y: 2)

            Text("O JOGO DE ESTRATÉGIA")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 1. Jogar contra bots (Hero primary CTA)
            Button(action: onPlayBots) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.25))
                            .frame(width: 42, height: 42)
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jogar contra bots")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Partida contra a IA")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.72, blue: 0.15),
                                    Color(red: 0.85, green: 0.50, blue: 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 0.95, green: 0.65, blue: 0.15).opacity(0.35), radius: 12, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleBounceButtonStyle())

            // 2. Online Multiplayer
            Button(action: onPlayOnline) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 42)
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HiveTheme.selection)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Online")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Partidas multiplayer e salas")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleBounceButtonStyle())

            // 3. Jogar Tutorial
            Button(action: onPlayTutorial) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 42)
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jogar Tutorial")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Aprenda as regras e táticas")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.07, green: 0.08, blue: 0.10)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - 3D Hexagon Showcase Component with Gyroscope Parallax & Interactive Flip

private struct Hero3DShowcase: View {
    private let bugRoster: [Bug] = [.queen, .spider, .beetle, .grasshopper, .ant, .mosquito, .ladybug]

    @StateObject private var motion = MotionManager()
    @State private var dragOffset: CGSize = .zero

    @State private var currentBugIndex = 0
    @State private var rotationY: Double = 0
    @State private var rotationX: Double = 0
    @State private var isFlipping = false
    @State private var tileColor: PlayerColor = .white
    @State private var glowScale: CGFloat = 1.0
    @State private var rotationTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentBug: Bug {
        bugRoster[currentBugIndex % bugRoster.count]
    }

    private var currentAccent: Color {
        HiveTheme.accent(currentBug, on: tileColor)
    }

    // Parallax calculations combining device motion + touch drag
    private var effectiveRoll: Double {
        motion.roll + Double(dragOffset.width / 130.0)
    }

    private var effectivePitch: Double {
        motion.pitch - Double(dragOffset.height / 130.0)
    }

    private var tiltX: Double {
        -effectivePitch * 26.0
    }

    private var tiltY: Double {
        effectiveRoll * 26.0
    }

    var body: some View {
        ZStack {
            // Ambient dynamic color halo glow with subtle parallax
            Circle()
                .fill(
                    RadialGradient(
                        colors: [currentAccent.opacity(0.42), currentAccent.opacity(0.0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 135
                    )
                )
                .frame(width: 270, height: 270)
                .scaleEffect(glowScale)
                .offset(x: effectiveRoll * 6, y: -effectivePitch * 6)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowScale)

            // Orbiting ambient micro-particles with middle-layer parallax
            ambientParticles
                .offset(x: effectiveRoll * 10, y: -effectivePitch * 10)

            // 3D Hexagon Tile with Gyro Parallax + Specular Reflection + Dynamic Shadow + Tap to Flip
            ZStack {
                TileView(
                    piece: Piece(id: -1, bug: currentBug, color: tileColor),
                    size: 58
                )
                .overlay {
                    // Specular light sheen that glints across the face as the phone tilts
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.24), location: max(0.1, min(0.9, 0.45 + effectiveRoll * 0.3 + effectivePitch * 0.3))),
                            .init(color: .clear, location: max(0.2, min(1.0, 0.70 + effectiveRoll * 0.3 + effectivePitch * 0.3)))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RegularHexagon())
                    .allowsHitTesting(false)
                }
                .shadow(
                    color: currentAccent.opacity(0.60),
                    radius: 24,
                    x: -effectiveRoll * 20,
                    y: 10 + effectivePitch * 20
                )
                .shadow(
                    color: .black.opacity(0.68),
                    radius: 18,
                    x: -effectiveRoll * 26,
                    y: 16 + effectivePitch * 26
                )
            }
            .contentShape(RegularHexagon())
            .offset(x: effectiveRoll * 14, y: -effectivePitch * 14)
            .rotation3DEffect(
                .degrees(rotationY + tiltY),
                axis: (x: 0.08, y: 1.0, z: 0.0),
                perspective: 0.60
            )
            .rotation3DEffect(
                .degrees(rotationX + tiltX),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                perspective: 0.60
            )
            .onTapGesture {
                flipToNextPiece()
                startRotationLoop()
            }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                            dragOffset = .zero
                        }
                    }
            )
        }
        .onAppear {
            glowScale = 1.15
            motion.start()
            if !reduceMotion {
                startRotationLoop()
            }
        }
        .onDisappear {
            rotationTask?.cancel()
            motion.stop()
        }
    }

    // MARK: - Floating Ambient Particles

    private var ambientParticles: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<6 {
                    let angle = Double(i) * (.pi / 3.0) + (t * 0.25)
                    let radius: CGFloat = 85 + CGFloat(sin(t * 1.5 + Double(i))) * 12
                    let x = center.x + cos(angle) * radius
                    let y = center.y + sin(angle) * radius * 0.55
                    let alpha = 0.35 + sin(t * 2.0 + Double(i)) * 0.25
                    let particleSize: CGFloat = 3.5 + CGFloat(sin(t + Double(i))) * 1.5

                    context.opacity = alpha
                    context.fill(
                        Circle().path(in: CGRect(x: x - particleSize / 2, y: y - particleSize / 2, width: particleSize, height: particleSize)),
                        with: .color(currentAccent)
                    )
                }
            }
            .frame(width: 240, height: 200)
            .allowsHitTesting(false)
        }
    }

    // MARK: - 3D Piece Flip & 20-Second Loop

    private func flipToNextPiece() {
        guard !isFlipping else { return }
        isFlipping = true
        Haptics.selection()

        Task { @MainActor in
            // Half flip
            withAnimation(.easeInOut(duration: 0.45)) {
                rotationY += 180
                rotationX = 14 * sin(rotationY * .pi / 180)
            }

            try? await Task.sleep(for: .milliseconds(225))
            // Swap bug and tile color at apex
            currentBugIndex = (currentBugIndex + 1) % bugRoster.count
            tileColor = tileColor == .white ? .black : .white

            try? await Task.sleep(for: .milliseconds(225))
            // Finish full flip
            withAnimation(.easeInOut(duration: 0.45)) {
                rotationY += 180
                rotationX = 0
            }

            try? await Task.sleep(for: .milliseconds(450))
            isFlipping = false
        }
    }

    private func startRotationLoop() {
        rotationTask?.cancel()
        rotationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                flipToNextPiece()
            }
        }
    }
}

// MARK: - Button Style

private struct ScaleBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
