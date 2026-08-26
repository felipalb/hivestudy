import SwiftUI
import HiveEngine

/// The main game menu / settings sheet.
///
/// Contains game actions (Pedir Dica, Jogar Tutorial, Como Jogar) along with
/// AI difficulty configuration and rules.
struct GameMenuSheet: View {
    let game: GameController
    var onStartTutorial: () -> Void = {}
    @State private var selectedDifficulty: HiveAI.Difficulty
    @Environment(\.dismiss) private var dismiss

    init(game: GameController, onStartTutorial: @escaping () -> Void = {}) {
        self.game = game
        self.onStartTutorial = onStartTutorial
        _selectedDifficulty = State(initialValue: UserPreferences.difficulty)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Game Actions (Dica, Tutorial, Regras) - all in white
                actionsSection

                // MARK: AI Difficulty
                settingsSections
            }
            .navigationTitle("Configurações e Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onDisappear {
            UserPreferences.difficulty = selectedDifficulty
            if game.currentCampaignLevel == nil {
                game.options.difficulty = selectedDifficulty
            }
        }
    }

    // MARK: - Actions Section (All text and icons in standard white)

    @ViewBuilder private var actionsSection: some View {
        Section("Ações") {
            // Pedir / Ocultar Dica
            let canHint = game.result == .ongoing && !game.isThinking && game.humanControls(game.current)
            let isHintShowing = game.hint != nil
            Button {
                if isHintShowing {
                    game.dismissHint()
                } else {
                    game.requestHint()
                }
                dismiss()
            } label: {
                HStack {
                    Label(
                        isHintShowing ? "Ocultar Dica" : "Pedir Dica",
                        systemImage: "lightbulb.fill"
                    )
                    .foregroundStyle(.white)
                    Spacer()
                    if game.isComputingHint {
                        ProgressView().controlSize(.mini).tint(.white)
                    }
                }
            }
            .disabled(!canHint && !isHintShowing)

            // Jogar Tutorial
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onStartTutorial()
                }
            } label: {
                Label("Jogar Tutorial", systemImage: "graduationcap.fill")
                    .foregroundStyle(.white)
            }

            // Como Jogar (Regras)
            NavigationLink {
                RulesView()
            } label: {
                Label("Como Jogar (Regras)", systemImage: "book.fill")
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Settings Sections

    @ViewBuilder private var settingsSections: some View {
        Section {
            Picker("Dificuldade", selection: $selectedDifficulty) {
                Text("Fácil").tag(HiveAI.Difficulty.easy)
                Text("Médio").tag(HiveAI.Difficulty.medium)
                Text("Difícil").tag(HiveAI.Difficulty.hard)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedDifficulty) { _, newValue in
                UserPreferences.difficulty = newValue
                if game.currentCampaignLevel == nil {
                    game.options.difficulty = newValue
                }
            }
        } header: {
            Text("Dificuldade do Oponente (IA)")
        } footer: {
            Text("Define o nível dos bots nas partidas livres. O Tutorial e o Modo Campanha possuem dificuldade adaptativa própria com dicas ativas.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

/// Concise reference of the rules. Designed to be *pushed* (it brings no
/// NavigationStack of its own) so it can live inside the menu sheet.
struct RulesView: View {
    /// Shared with `OnboardingOverlay`'s "The Tiles" page.
    static let bugs: [(Bug, String)] = [
        (.queen, "Move um espaço. Perde quando todos os seus seis lados estão cercados."),
        (.beetle, "Move um espaço e pode subir no topo da formação, imobilizando a peça abaixo."),
        (.grasshopper, "Pula em linha reta sobre uma ou mais peças até a primeira célula vazia."),
        (.spider, "Move exatamente três espaços ao redor da formação, sem retroceder."),
        (.ant, "Move qualquer número de espaços ao redor da formação."),
        (.mosquito, "Copia o movimento de qualquer criatura que tocar. No topo da formação, só se move como Gorila."),
        (.ladybug, "Move exatamente três espaços: dois pelo topo da formação, depois um descendo em uma célula vazia.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Objetivo", "Cerque completamente o Leão do oponente — todos os seis lados cobertos por peças de qualquer cor. Se ambos os Leões forem cercados ao mesmo tempo, é empate.")

                section("Turnos", "A cada turno, coloque uma nova peça da sua mão ou mova uma peça já em jogo. Novas peças devem tocar sua própria cor e nunca tocar a do oponente (exceto as peças iniciais).")

                section("O Leão", "Seu Leão deve ser colocado até o quarto turno, e nenhuma peça pode ser movida até que ele esteja no campo.")

                section("Colmeia Unida (Sustentação)", "O campo funciona como uma corrente única e contínua: nunca pode ser dividido em dois grupos. Qualquer peça que esteja sustentando a ligação da colmeia (ponto de sustentação) não pode se mover. As peças que deslizam também precisam de espaço físico livre para passar.")

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
