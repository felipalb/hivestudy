import SwiftUI
import HiveEngine

struct ContentView: View {
    @State private var game = GameController()
    @State private var showMenu = false
    @State private var showLeaveConfirm = false
    @State private var showOnboarding = !OnboardingState.hasSeenTutorial
    @State private var showTutorial = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            BoardView(game: game, onStartTutorial: { showTutorial = true })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
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
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.result)
        .animation(.easeInOut(duration: 0.25), value: game.pendingResume != nil)
        .animation(.easeInOut(duration: 0.2), value: showLeaveConfirm)
        .animation(.easeInOut(duration: 0.25), value: showOnboarding)
        .animation(.easeInOut(duration: 0.25), value: showTutorial)
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
            circleButton("arrow.uturn.backward", enabled: game.canUndo) { game.undo() }
            Spacer(minLength: 8)
            statusPill
            Spacer(minLength: 8)
            // Before play begins the button opens setup; once a tile is down it
            // becomes an "X" that asks to confirm leaving the match.
            if game.hasStarted {
                circleButton("xmark") { showLeaveConfirm = true }
            } else {
                circleButton("slider.horizontal.3") { showMenu = true }
            }
        }
        .padding(.top, 4)
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if game.isThinking {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Circle()
                    .fill(HiveTheme.tileGradient(game.current))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(HiveTheme.tileBorder(game.current), lineWidth: 1))
            }
            Text(game.statusText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            surroundBadges
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
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
                }
            }
        }
    }

    private func circleButton(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
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
    }

    // MARK: Trays

    private var trays: some View {
        VStack(spacing: 8) {
            HandTrayView(game: game, color: .black)
            HandTrayView(game: game, color: .white)
        }
        .padding(.bottom, 6)
    }
}

/// Result card shown when a queen is surrounded (or a draw).
private struct GameOverOverlay: View {
    let game: GameController
    let onPlayAgain: () -> Void
    let onChangeSetup: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { }   // swallow taps
            VStack(spacing: 18) {
                Image(systemName: iconName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    bigButton("Play Again", filled: true, action: onPlayAgain)
                    HStack(spacing: 10) {
                        bigButton("Undo", filled: false) { game.undo() }
                        bigButton("Setup", filled: false, action: onChangeSetup)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(overlayCard)
            .padding(30)
        }
    }

    private var title: String {
        switch game.result {
        case .win(let c): return "\(c == .white ? "White" : "Black") Wins"
        case .draw: return "Draw"
        case .ongoing: return ""
        }
    }
    private var subtitle: String {
        switch game.result {
        case .win: return "The Queen Bee is completely surrounded."
        case .draw: return "Both Queen Bees fell at once."
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
                Text("Welcome Back")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("You have a game in progress. Pick up where you left off?")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    button("Continue Game", filled: true, action: onContinue)
                    button("Leave Game", filled: false, action: onLeave)
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
                Text("Leave the game?")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("This ends the current match. You can't undo it.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    button("Yes, leave", filled: true, action: onLeave)
                    button("Continue", filled: false, action: onContinue)
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

/// Shared frosted card background for the modal overlays (also used by
/// `OnboardingOverlay`).
var overlayCard: some View {
    RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(.white.opacity(0.12), lineWidth: 1))
}
