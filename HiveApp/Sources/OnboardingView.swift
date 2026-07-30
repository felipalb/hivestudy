import SwiftUI
import HiveEngine

/// Tracks whether the player has been through the first-launch tutorial.
/// Deliberately separate from `GamePersistence` (a match cache) — this is a
/// one-time, permanent flag, never cleared by `newGame`/`leaveMatch`.
enum OnboardingState {
    private static let key = "hive.hasSeenOnboarding.v1"
    private static let defaults = UserDefaults.standard

    static var hasSeenTutorial: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

/// Shown once, the very first time the app is opened — before the resume/menu
/// overlays get a chance to. A paged walkthrough of the goal, turn structure,
/// the Queen/One-Hive rules, the tile roster, and a few strategy tips, ending
/// on a choice: play a guided match against the tutorial bot, or go straight
/// into a real game. `onFinish(true)` means "start the tutorial match";
/// `onFinish(false)` means "just dismiss" (including Skip, at any page).
struct OnboardingOverlay: View {
    let onFinish: (_ startTutorial: Bool) -> Void
    @State private var page = 0

    private let pageCount = 8

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
                .onTapGesture { }   // swallow taps

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button("Skip") { onFinish(false) }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .opacity(page == pageCount - 1 ? 0 : 1)      // the last page has its own explicit choices
                        .disabled(page == pageCount - 1)
                }

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    goalPage.tag(1)
                    turnsPage.tag(2)
                    queenPage.tag(3)
                    oneHivePage.tag(4)
                    tilesPage.tag(5)
                    tipsPage.tag(6)
                    readyPage.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 540)

                if page < pageCount - 1 {
                    bigButton("Next", filled: true) {
                        withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 400)
            .background(overlayCard)
            .padding(24)
        }
    }

    // MARK: Pages

    private var welcomePage: some View {
        pageBody(icon: "hexagon.fill",
                 title: "Welcome to Hive",
                 text: "Surround your opponent's Queen Bee before they surround yours. No board, no dice — just the tiles.")
    }

    private var goalPage: some View {
        pageBody(icon: "target",
                 title: "The Goal",
                 text: "Completely surround your opponent's Queen Bee — all six sides covered by tiles of any colour. If both Queens are surrounded at once, it's a draw.")
    }

    private var turnsPage: some View {
        pageBody(icon: "arrow.triangle.2.circlepath",
                 title: "Your Turn",
                 text: "Each turn, place a new tile from your hand or move a tile already in play. New tiles must touch your own colour and never touch the opponent's (except the opening tiles).")
    }

    private var queenPage: some View {
        pageBody(icon: "crown.fill",
                 title: "The Queen",
                 text: "Your Queen must be placed by your fourth turn, and you can't move any tile until she's on the board.")
    }

    private var oneHivePage: some View {
        pageBody(icon: "link",
                 title: "One Hive",
                 text: "The hive must stay connected at all times. A tile that would split the hive when lifted cannot move. Tiles slide — they can't squeeze through a gap that's blocked on both sides.")
    }

    private var tilesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("The Tiles")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                ForEach(RulesView.bugs, id: \.0) { bug, text in
                    HStack(alignment: .top, spacing: 12) {
                        TileView(piece: Piece(id: -1, bug: bug, color: .white), size: 20)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bug.displayName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(text)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 28)   // clears the page-index dots the .page style overlays at the bottom
        }
    }

    private var tipsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("A Few Tips")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                tip("clock.fill",
                    "Don't rush your Queen out where she's easy to surround — but don't stall past turn four either.")
                tip("arrow.up.and.down.circle.fill",
                    "A Beetle on top of a tile pins whatever's underneath it. Climb one onto a key defender to freeze it in place.")
                tip("arrow.triangle.branch",
                    "The Mosquito copies the move of any bug it touches — and once it climbs atop the hive, it can only move like a Beetle from then on.")
                tip("point.topleft.down.curvedto.point.bottomright.up",
                    "The Ant can slide anywhere around the outside of the hive. It's your most flexible piece — often worth saving to finish a surround rather than spending early.")
                tip("hexagon",
                    "Keep counting sides: watch your own Queen's open faces as closely as your opponent's.")
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 28)   // clears the page-index dots the .page style overlays at the bottom
        }
    }

    private var readyPage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)
            Image(systemName: "flag.checkered")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(HiveTheme.selection)
            Text("Ready to Play")
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Play a guided match against a very forgiving bot to try out what you've just learned, or jump straight into a real game.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                bigButton("Play Tutorial", filled: true) {
                    OnboardingState.hasSeenTutorial = true
                    onFinish(true)
                }
                bigButton("Start Playing", filled: false) {
                    OnboardingState.hasSeenTutorial = true
                    onFinish(false)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 30)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HiveTheme.selection)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func pageBody(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)
            Image(systemName: icon)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(HiveTheme.selection)
            Text(title)
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 30)
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
        .padding(.horizontal, 4)
    }
}
