import SwiftUI
import HiveEngine

/// Configuration sheet for starting (or restarting) a game.
struct NewGameSheet: View {
    @State private var options: GameOptions
    let onStart: (GameOptions) -> Void
    let onShowRules: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(current: GameOptions,
         onStart: @escaping (GameOptions) -> Void,
         onShowRules: @escaping () -> Void) {
        _options = State(initialValue: current)
        self.onStart = onStart
        self.onShowRules = onShowRules
    }

    var body: some View {
        NavigationStack {
            Form {
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
                            ForEach(HiveAI.Difficulty.allCases, id: \.self) { d in
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

                Section {
                    Button {
                        onShowRules()
                    } label: {
                        Label("How to play", systemImage: "book.fill")
                    }
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { onStart(options) }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

/// Concise reference of the rules, reachable from the setup sheet.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    private let bugs: [(Bug, String)] = [
        (.queen, "Moves one space. Lose when all six of its sides are covered."),
        (.beetle, "Moves one space and can climb on top of the hive, pinning the tile beneath."),
        (.grasshopper, "Jumps in a straight line over one or more tiles to the first empty cell."),
        (.spider, "Moves exactly three spaces around the hive, never backtracking."),
        (.ant, "Moves any number of spaces around the outside of the hive.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Goal", "Completely surround your opponent's Queen Bee — all six sides covered by tiles of any colour. If both Queens are surrounded at once, it's a draw.")

                    section("Turns", "Each turn, place a new tile from your hand or move a tile already in play. New tiles must touch your own colour and never touch the opponent's (except the opening tiles).")

                    section("The Queen", "Your Queen must be placed by your fourth turn, and you cannot move any tile until she is on the board.")

                    section("One Hive", "The hive must stay connected at all times. A tile that would split the hive when lifted cannot move. Tiles slide — they can't squeeze through a gap that's blocked on both sides.")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Tiles")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                        ForEach(bugs, id: \.0) { bug, text in
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
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
