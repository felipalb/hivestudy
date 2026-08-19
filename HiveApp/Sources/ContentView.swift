import SwiftUI
import HiveEngine

struct ContentView: View {
    @State private var game = GameController()
    @State private var showMenu = false
    @State private var showLeaveConfirm = false
    @State private var showOnboarding = !OnboardingState.hasSeenTutorial
    @State private var showTutorial = false
    /// The board piece the player is pressing-and-holding to inspect; non-nil
    /// while the movement-explanation modal is up.
    @State private var inspectedPiece: Piece?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            BoardView(game: game,
                      onStartTutorial: { showTutorial = true },
                      onInspectPiece: { inspectedPiece = $0 })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                // Short-lived coaching/error messages — the app's answer to
                // taps that didn't do what the player expected.
                if let toast = game.toast {
                    ToastPill(toast: toast)
                        .id(toast.id)   // a new message re-runs the entrance
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
                // Subtle coaching that a held piece reveals its movement rules —
                // for a picked-up board tile or a selected hand chip alike.
                if game.isPieceSelected {
                    selectionHint
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                trays
            }
            .padding(.horizontal, 12)

            if game.result != .ongoing {
                GameOverOverlay(
                    game: game,
                    onPlayAgain: { game.newGame() },
                    onChangeSetup: { showMenu = true }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // A match interrupted by the app being killed: let the player pick up
            // where they left off, or drop it.
            if game.pendingResume != nil {
                ResumeOverlay(
                    onContinue: { game.resume() },
                    onLeave: { game.discardResume() }
                )
                .transition(.opacity)
            }

            // Confirm before abandoning a match in progress (opened by the
            // top-bar "X", which replaces the settings button once play begins).
            if showLeaveConfirm {
                LeaveConfirmOverlay(
                    onLeave: { game.leaveMatch(); showLeaveConfirm = false },
                    onContinue: { showLeaveConfirm = false }
                )
                .transition(.opacity)
                .zIndex(5)
            }

            // First launch only: a short onboarding walkthrough, on top of
            // everything else. Its "Play Tutorial" choice launches the guided
            // tutorial overlay below.
            if showOnboarding {
                OnboardingOverlay(onFinish: { startTutorial in
                    showOnboarding = false
                    if startTutorial { showTutorial = true }
                })
                .transition(.opacity)
                .zIndex(10)
            }

            // The interactive, fully-guided tutorial. Owned here (not BoardView)
            // so it sits above the whole UI and never affects the live game —
            // exiting just returns to whatever was on the board.
            if showTutorial {
                TutorialView(
                    onExit: { showTutorial = false },
                    onPlayGame: { showTutorial = false; game.newGame() }
                )
                .transition(.opacity)
                .zIndex(15)
            }

            // Opened by press-and-holding a tile on the board: a focused card
            // explaining just that piece's movement.
            if let piece = inspectedPiece {
                PieceMoveInfoOverlay(piece: piece, onDismiss: { inspectedPiece = nil })
                    .transition(.opacity)
                    .zIndex(8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.result)
        .animation(.easeInOut(duration: 0.25), value: game.pendingResume != nil)
        .animation(.easeInOut(duration: 0.2), value: showLeaveConfirm)
        .animation(.easeInOut(duration: 0.25), value: showOnboarding)
        .animation(.easeInOut(duration: 0.25), value: showTutorial)
        .animation(.easeInOut(duration: 0.2), value: inspectedPiece)
        .animation(.easeInOut(duration: 0.2), value: game.isPieceSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.toast)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMenu) { GameMenuSheet(game: game) }
        // Cache the match whenever the app leaves the foreground, so nothing is
        // lost even if it's killed in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.persistNow() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            circleButton("arrow.uturn.backward", label: "Desfazer jogada", enabled: game.canUndo) { game.undo() }
            Spacer(minLength: 8)
            statusPill
            Spacer(minLength: 8)
            // Before play begins the button opens setup; once a tile is down it
            // becomes an "X" that asks to confirm leaving the match.
            if game.hasStarted {
                circleButton("xmark", label: "Sair da partida") { showLeaveConfirm = true }
            } else {
                circleButton("slider.horizontal.3", label: "Configurar novo jogo") { showMenu = true }
            }
        }
        .padding(.top, 4)
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if game.isThinking {
                ThinkingDots()
            } else {
                Circle()
                    .fill(HiveTheme.tileGradient(game.current))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(HiveTheme.tileBorder(game.current), lineWidth: 1))
            }
            Text(game.statusText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                // Crossfade whenever the message changes (turn passes, the AI
                // starts/stops thinking, the queen becomes mandatory) instead of
                // snapping — makes the flow of play readable at a glance.
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: game.statusText)
            surroundBadges
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: game.current)
        .accessibilityElement(children: .combine)
    }

    /// Tiny "sides of each queen filled" indicators — the core tension of Hive.
    private var surroundBadges: some View {
        HStack(spacing: 6) {
            ForEach(PlayerColor.allCases, id: \.self) { color in
                let count = game.state.queenSurroundCount(color)
                if game.state.queenHex(color) != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(count >= 5 ? HiveTheme.danger : HiveTheme.tileBorder(color))
                        Text("\(count)/6")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(count >= 5 ? HiveTheme.danger : .secondary)
                    }
                    .animation(.easeInOut(duration: 0.3), value: count)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Rainha \(color == .white ? "branca" : "preta") com \(count) de 6 lados cercados"
                    )
                }
            }
        }
    }

    private func circleButton(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: Trays

    private var trays: some View {
        VStack(spacing: 8) {
            HandTrayView(game: game, color: .black, onInspectPiece: { inspectedPiece = $0 })
            HandTrayView(game: game, color: .white, onInspectPiece: { inspectedPiece = $0 })
        }
        .padding(.bottom, 6)
    }

    /// Sits just above the hand trays while a board piece is picked up, nudging
    /// the player to press-and-hold for that piece's movement rules.
    private var selectionHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Segure para ver o movimento da peça")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.bottom, 10)
    }
}

/// One short-lived coaching/error message. Sits above the hand trays; the
/// controller decides text + icon, auto-dismissal included.
private struct ToastPill: View {
    let toast: GameController.Toast

    var body: some View {
        HStack(spacing: 7) {
            if let icon = toast.icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HiveTheme.selection)
            }
            Text(toast.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

/// Three dots that light up in sequence while the AI searches — livelier and
/// more "someone is thinking" than a bare spinner. Under Reduce Motion it falls
/// back to the quiet system spinner.
private struct ThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ProgressView().controlSize(.small).tint(.white)
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 3.5) {
                    ForEach(0..<3, id: \.self) { i in
                        let wave = sin(t * 3.0 - Double(i) * 0.8) * 0.5 + 0.5
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .opacity(0.25 + 0.75 * wave)
                            .scaleEffect(0.8 + 0.35 * wave)
                    }
                }
            }
            .frame(width: 30, height: 16)
            .accessibilityHidden(true)   // the status text already says "thinking"
        }
    }
}

/// Result card shown when a queen is surrounded (or a draw).
private struct GameOverOverlay: View {
    let game: GameController
    let onPlayAgain: () -> Void
    let onChangeSetup: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { }   // swallow taps

            // Victory particles (only on win, not draw, and only when the
            // player hasn't asked the system to tone motion down).
            if case .win = game.result, !reduceMotion {
                VictoryParticles()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                Image(systemName: iconName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(iconColor)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .opacity(appeared ? 1.0 : 0.0)
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1.0 : 0.0)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1.0 : 0.0)

                VStack(spacing: 10) {
                    bigButton("Jogar Novamente", filled: true, action: onPlayAgain)
                        .opacity(appeared ? 1.0 : 0.0)
                    HStack(spacing: 10) {
                        bigButton("Desfazer", filled: false) { game.undo() }
                        bigButton("Configurar", filled: false, action: onChangeSetup)
                    }
                    .opacity(appeared ? 1.0 : 0.0)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(overlayCard)
            .padding(30)
            .scaleEffect(appeared ? 1.0 : 0.92)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .onAppear {
            // Stagger animation for each element — or show everything at once
            // when Reduce Motion is on (no scaling/sliding entrance).
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            }
        }
    }

    private var title: String {
        switch game.result {
        case .win(let c): return "\(c == .white ? "Brancas" : "Pretas") Vencem"
        case .draw: return "Empate"
        case .ongoing: return ""
        }
    }
    private var subtitle: String {
        switch game.result {
        case .win: return "A Rainha está completamente cercada."
        case .draw: return "Ambas as Rainhas foram cercadas ao mesmo tempo."
        case .ongoing: return ""
        }
    }
    private var iconName: String {
        if case .draw = game.result { return "equal.circle.fill" }
        return "crown.fill"
    }
    private var iconColor: Color {
        if case .draw = game.result { return .secondary }
        return HiveTheme.accent(.queen)
    }

    private func bigButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(filled ? HiveTheme.selection : Color.white.opacity(0.10))
                )
                .foregroundStyle(filled ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}

/// Offered at launch when a match was interrupted by the app closing.
private struct ResumeOverlay: View {
    let onContinue: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { }
            VStack(spacing: 18) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(HiveTheme.selection)
                Text("Bem-vindo de Volta")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Você tem uma partida em andamento. Continuar de onde parou?")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    button("Continuar Jogo", filled: true, action: onContinue)
                    button("Abandonar Jogo", filled: false, action: onLeave)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(overlayCard)
            .padding(30)
        }
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(filled ? HiveTheme.selection : Color.white.opacity(0.10))
                )
                .foregroundStyle(filled ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}

/// Confirm before abandoning a match in progress (from the top-bar "X").
private struct LeaveConfirmOverlay: View {
    let onLeave: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { onContinue() }
            VStack(spacing: 18) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(HiveTheme.danger)
                Text("Sair da partida?")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Isso encerra a partida atual. Não é possível desfazer.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    button("Sim, sair", filled: true, action: onLeave)
                    button("Continuar", filled: false, action: onContinue)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(overlayCard)
            .padding(30)
        }
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(filled ? HiveTheme.danger : Color.white.opacity(0.10))
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// Explains a single piece's movement, opened by press-and-holding that tile on
/// the board. The blurb is the same one the rules screen uses, so both stay in
/// sync from one source (`RulesView.bugs`).
private struct PieceMoveInfoOverlay: View {
    let piece: Piece
    let onDismiss: () -> Void

    private var movementText: String {
        RulesView.bugs.first { $0.0 == piece.bug }?.1
            ?? "Toque em uma célula destacada para mover esta peça."
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 14) {
                // Animated mini-diagram showing how the bug moves
                MovementDiagramView(bug: piece.bug)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.black.opacity(0.25))
                    )
                    .accessibilityLabel("Diagrama animado do movimento \(piece.bug.displayName)")

                HStack(spacing: 10) {
                    TileView(piece: piece, size: 20)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    Text(piece.bug.displayName)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text(movementText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("Entendi")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(HiveTheme.selection)
                        )
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(overlayCard)
            .padding(30)
        }
    }
}

/// Shared frosted card background for the modal overlays (also used by
/// `OnboardingOverlay`).
var overlayCard: some View {
    RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(.white.opacity(0.12), lineWidth: 1))
}

/// Hex-shaped confetti particles that burst across the screen on victory.
private struct VictoryParticles: View {
    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let rotation: Double
        let drift: CGFloat
    }

    @State private var particles: [Particle] = []
    @State private var animate = false

    private let palette: [Color] = [
        HiveTheme.accent(.queen),
        HiveTheme.accent(.ant),
        HiveTheme.accent(.grasshopper),
        HiveTheme.accent(.beetle),
        HiveTheme.selection,
        .white.opacity(0.8)
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for p in particles {
                        let elapsed = now - p.delay
                        guard elapsed > 0 else { continue }
                        let t = min(1.0, elapsed / p.duration)

                        let y = -size.height * 0.1 + CGFloat(t) * size.height * 1.3
                        let x = p.x + sin(elapsed * 2.0 + Double(p.drift)) * 30
                        let opacity = t < 0.1 ? t / 0.1 : (t > 0.8 ? (1.0 - t) / 0.2 : 1.0)
                        let angle = elapsed * p.rotation

                        var transform = context
                        transform.translateBy(x: x, y: y)
                        transform.rotate(by: .radians(angle))
                        transform.opacity = opacity

                        let hexPath = regularHexagonPath(size: p.size)
                        transform.fill(hexPath, with: .color(p.color))
                    }
                }
            }
            .onAppear {
                guard particles.isEmpty else { return }
                particles = (0..<40).map { _ in
                    Particle(
                        x: CGFloat.random(in: 0...geo.size.width),
                        delay: Double.random(in: 0...1.5),
                        duration: Double.random(in: 2.0...4.0),
                        size: CGFloat.random(in: 6...16),
                        color: palette.randomElement()!,
                        rotation: Double.random(in: -3...3),
                        drift: CGFloat.random(in: 0...6)
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    private func regularHexagonPath(size: CGFloat) -> Path {
        var path = Path()
        let r = size / 2
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: r * cos(angle), y: r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
