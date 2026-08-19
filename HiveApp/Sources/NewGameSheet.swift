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
            .navigationTitle(game.hasStarted ? "Menu" : "Novo Jogo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }.fontWeight(.semibold)
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
        Section("Oponente") {
            Picker("Modo", selection: $options.mode) {
                ForEach(GameOptions.Mode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if options.mode == .vsAI {
                Picker("Você joga de", selection: $options.humanColor) {
                    Text("Brancas (primeiro)").tag(PlayerColor.white)
                    Text("Pretas").tag(PlayerColor.black)
                }
                Picker("Dificuldade", selection: $options.difficulty) {
                    // megaEasy is a hidden tier reserved for "Play Tutorial" above.
                    ForEach(HiveAI.Difficulty.allCases.filter { $0 != .megaEasy }, id: \.self) { d in
                        Text(d.displayLabel).tag(d)
                    }
                }
            }
        }

        Section {
            Toggle("Abertura de torneio", isOn: $options.tournamentOpening)
        } header: {
            Text("Regras")
        } footer: {
            Text("A abertura de torneio proibe colocar a Rainha como primeira peça.")
        }
    }

    // MARK: While a match is in progress

    @ViewBuilder private var startedSections: some View {
        Section {
            Button(role: .destructive) {
                game.leaveMatch()
                dismiss()
            } label: {
                Label("Abandonar Partida", systemImage: "flag.fill")
            }
        } footer: {
            Text("Encerra o jogo atual e permite escolher novas configurações.")
        }
    }
}

/// Concise reference of the rules. Designed to be *pushed* (it brings no
/// NavigationStack of its own) so it can live inside the menu sheet.
struct RulesView: View {
    /// Shared with `OnboardingOverlay`'s "The Tiles" page.
    static let bugs: [(Bug, String)] = [
        (.queen, "Move um espaço. Perde quando todos os seis lados estão cobertos."),
        (.beetle, "Move um espaço e pode subir no topo da colmeia, imobilizando a peça abaixo."),
        (.grasshopper, "Pula em linha reta sobre uma ou mais peças até a primeira célula vazia."),
        (.spider, "Move exatamente três espaços ao redor da colmeia, sem retroceder."),
        (.ant, "Move qualquer número de espaços ao redor da colmeia."),
        (.mosquito, "Copia o movimento de qualquer inseto que tocar. No topo da colmeia, só se move como Besouro."),
        (.ladybug, "Move exatamente três espaços: dois pelo topo da colmeia, depois um de volta para uma célula vazia.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Objetivo", "Cerque completamente a Rainha do oponente — todos os seis lados cobertos por peças de qualquer cor. Se ambas as Rainhas forem cercadas ao mesmo tempo, é empate.")

                section("Turnos", "A cada turno, coloque uma nova peça da sua mão ou mova uma peça já em jogo. Novas peças devem tocar sua própria cor e nunca tocar a do oponente (exceto as peças iniciais).")

                section("A Rainha", "Sua Rainha deve ser colocada até o quarto turno, e nenhuma peça pode ser movida até que ela esteja no tabuleiro.")

                section("Uma Colmeia", "A colmeia deve permanecer conectada o tempo todo. Uma peça que dividiria a colmeia ao ser levantada não pode se mover. As peças deslizam — não podem passar por uma abertura bloqueada dos dois lados.")

                VStack(alignment: .leading, spacing: 12) {
                    Text("As Peças")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                    ForEach(Self.bugs, id: \.0) { bug, text in
                        HStack(alignment: .top, spacing: 12) {
                            TileView(piece: Piece(id: -1, bug: bug, color: .white), size: 20)
                                .frame(width: 44, height: 44)
                                .accessibilityHidden(true)   // the name beside it is read instead
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
        .navigationTitle("Como Jogar")
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
