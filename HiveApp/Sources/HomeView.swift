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
///   2. "Online" -> placeholder with "Em breve" badge.
///   3. "Jogar tutorial" -> launches guided interactive tutorial.
struct HomeView: View {
    let onPlayBots: () -> Void
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

                // Action Buttons
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
            Text("H I V E")
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

            // 2. Online (Em breve)
            Button(action: triggerOnlineNotice) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 42)
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Online")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Partidas multiplayer")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("EM BREVE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(HiveTheme.selection)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(HiveTheme.selection.opacity(0.15)))
                        .overlay(Capsule().stroke(HiveTheme.selection.opacity(0.3), lineWidth: 1))
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

    private func triggerOnlineNotice() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        showOnlineToast = true
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            showOnlineToast = false
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

// MARK: - 3D Hexagon Showcase Component

private struct Hero3DShowcase: View {
    private let bugRoster: [Bug] = [.queen, .spider, .beetle, .grasshopper, .ant, .mosquito, .ladybug]

    @State private var currentBugIndex = 0
    @State private var rotationY: Double = 0
    @State private var rotationX: Double = 0
    @State private var isFlipping = false
    @State private var tileColor: PlayerColor = .white
    @State private var glowScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentBug: Bug {
        bugRoster[currentBugIndex % bugRoster.count]
    }

    private var currentAccent: Color {
        HiveTheme.accent(currentBug, on: tileColor)
    }

    var body: some View {
        ZStack {
            // Ambient dynamic color halo glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [currentAccent.opacity(0.40), currentAccent.opacity(0.0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(glowScale)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowScale)

            // Orbiting ambient micro-particles
            ambientParticles

            VStack(spacing: 12) {
                // 3D Hexagon Tile
                ZStack {
                    TileView(
                        piece: Piece(id: -1, bug: currentBug, color: tileColor),
                        size: 58
                    )
                    .shadow(color: currentAccent.opacity(0.6), radius: 24, y: 8)
                    .shadow(color: .black.opacity(0.6), radius: 16, y: 12)
                }
                .rotation3DEffect(
                    .degrees(rotationY),
                    axis: (x: 0.12, y: 1.0, z: 0.0),
                    perspective: 0.65
                )
                .rotation3DEffect(
                    .degrees(rotationX),
                    axis: (x: 1.0, y: 0.0, z: 0.0),
                    perspective: 0.65
                )

                // Bug Name Badge with matching accent
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentAccent)
                        .frame(width: 6, height: 6)
                    Text(currentBug.displayName.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(currentAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .overlay(Capsule().stroke(currentAccent.opacity(0.4), lineWidth: 1))
                .animation(.easeInOut(duration: 0.35), value: currentBugIndex)
            }
        }
        .onAppear {
            glowScale = 1.15
            if !reduceMotion {
                startRotationLoop()
            }
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

    // MARK: - 3D Animation Loop

    private func startRotationLoop() {
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(2.8))

                // Perform a dynamic 360 degree flip
                withAnimation(.easeInOut(duration: 0.9)) {
                    rotationY += 180
                    rotationX = 12 * sin(rotationY * .pi / 180)
                }

                try? await Task.sleep(for: .milliseconds(450))
                // Swap bug and tile color at the 90° flip apex
                currentBugIndex = (currentBugIndex + 1) % bugRoster.count
                tileColor = tileColor == .white ? .black : .white

                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeInOut(duration: 0.9)) {
                    rotationY += 180
                    rotationX = 0
                }
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
