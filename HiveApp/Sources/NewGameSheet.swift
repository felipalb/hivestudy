import SwiftUI
import HiveEngine

/// The single game menu / setup sheet.
///
/// There is no "Start" button: before the match begins the settings apply to the
/// current game when the sheet closes. Once play is under way the settings are
/// hidden — only "How to Play" remains, alongside "Leave Match". "How to Play" is
/// *pushed* inside this sheet's own NavigationStack (never a second sheet), which
/// is what previously caused the "only a single sheet is supported" error.
struct GameMenuSheet: View {
    let game: GameController
    @State private var options: GameOptions
    @Environment(\.dismiss) private var dismiss

    init(game: GameController) {
        self.game = game
        _options = State(initialValue: game.options)
    }

    var body: some View {
        NavigationStack {
            Form {
                if game.hasStarted {
                    startedSections
                } else {
                    setupSections
                }
            }
            .navigationTitle(game.hasStarted ? "Menu" : "New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        // No "Start": closing the sheet commits the chosen settings to the
        // not-yet-started game (a no-op once play has begun).
        .onDisappear { game.applySetup(options) }
    }

    // MARK: Before the match begins

    @ViewBuilder private var setupSections: some View {
        Section("Opponent") {
            Picker("Mode", selection: $options.mode) {
                ForEach(GameOptions.Mode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if options.mode == .vsAI {
                Picker("You play", selection: $options.humanColor) {
                    Text("White (first)").tag(PlayerColor.white)
                    Text("Black").tag(PlayerColor.black)
                }
                Picker("Difficulty", selection: $options.difficulty) {
                    // megaEasy is a hidden tier reserved for "Play Tutorial" above.
                    ForEach(HiveAI.Difficulty.allCases.filter { $0 != .megaEasy }, id: \.self) { d in
                        Text(d.rawValue.capitalized).tag(d)
                    }
                }
            }
        }

        Section {
            Toggle("Tournament opening", isOn: $options.tournamentOpening)
        } header: {
            Text("Rules")
        } footer: {
            Text("Tournament opening forbids placing the Queen Bee as your very first tile.")
        }
    }

    // MARK: While a match is in progress

    @ViewBuilder private var startedSections: some View {
        Section {
            Button(role: .destructive) {
                game.leaveMatch()
                dismiss()
            } label: {
                Label("Leave Match", systemImage: "flag.fill")
            }
        } footer: {
            Text("Ends the current game and lets you choose new settings.")
        }
    }
}

/// Concise reference of the rules. Designed to be *pushed* (it brings no
/// NavigationStack of its own) so it can live inside the menu sheet.
struct RulesView: View {
    /// Shared with `OnboardingOverlay`'s "The Tiles" page.
    static let bugs: [(Bug, String)] = [
        (.queen, "Moves one space. Lose when all six of its sides are covered."),
        (.beetle, "Moves one space and can climb on top of the hive, pinning the tile beneath."),
        (.grasshopper, "Jumps in a straight line over one or more tiles to the first empty cell."),
        (.spider, "Moves exactly three spaces around the hive, never backtracking."),
        (.ant, "Moves any number of spaces around the outside of the hive."),
        (.mosquito, "Copies the move of any bug it touches. Atop the hive, it can only move like a Beetle."),
        (.ladybug, "Moves exactly three spaces: two across the top of the hive, then one back down to an empty cell.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Goal", "Completely surround your opponent's Queen Bee — all six sides covered by tiles of any colour. If both Queens are surrounded at once, it's a draw.")

                section("Turns", "Each turn, place a new tile from your hand or move a tile already in play. New tiles must touch your own colour and never touch the opponent's (except the opening tiles).")

                section("The Queen", "Your Queen must be placed by your fourth turn, and you cannot move any tile until she is on the board.")

                section("One Hive", "The hive must stay connected at all times. A tile that would split the hive when lifted cannot move. Tiles slide — they can't squeeze through a gap that's blocked on both sides.")

                VStack(alignment: .leading, spacing: 12) {
                    Text("The Tiles")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                    ForEach(Self.bugs, id: \.0) { bug, text in
                        HStack(alignment: .top, spacing: 12) {
                            TileView(piece: Piece(id: -1, bug: bug, color: .white), size: 20)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bug.displayName)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Text(text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}
