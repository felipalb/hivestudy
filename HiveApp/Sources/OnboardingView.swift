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
                    Button("Pular") { onFinish(false) }
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
                    bigButton("Próximo", filled: true) {
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
                 title: "Bem-vindo ao Huli",
                 text: "Cerque o Leão do oponente antes que ele cerque o seu. Sem tabuleiro, sem dados — apenas as criaturas e sua estratégia.")
    }

    private var goalPage: some View {
        pageBody(icon: "target",
                 title: "O Objetivo",
                 text: "Cerque completamente o Leão do oponente — todos os seis lados cobertos por peças de qualquer cor. Se ambos os Leões forem cercados ao mesmo tempo, é empate.")
    }

    private var turnsPage: some View {
        pageBody(icon: "arrow.triangle.2.circlepath",
                 title: "Seu Turno",
                 text: "A cada turno, coloque uma nova peça da sua mão ou mova uma peça já em jogo. Novas peças devem tocar sua própria cor e nunca tocar a do oponente (exceto as peças iniciais).")
    }

    private var queenPage: some View {
        pageBody(icon: "crown.fill",
                 title: "O Leão",
                 text: "Seu Leão deve ser colocado até o quarto turno, e nenhuma peça pode ser movida até que ele esteja no campo.")
    }

    private var oneHivePage: some View {
        pageBody(icon: "link",
                 title: "Colmeia Unida (Sustentação)",
                 text: "A colmeia funciona como uma corrente contínua — nunca pode se partir em dois grupos. Qualquer peça que esteja sustentando a ligação da colmeia fica travada e não pode sair. Além disso, as peças deslizam e não passam por portões bloqueados.")
    }

    private var tilesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("As Peças")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                ForEach(RulesView.bugs, id: \.0) { bug, text in
                    HStack(alignment: .top, spacing: 12) {
                        TileView(piece: Piece(id: -1, bug: bug, color: .white), size: 20)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)   // the name beside it is read instead
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
                Text("Algumas Dicas")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                tip("clock.fill",
                    "Não apresse seu Leão para onde ele possa ser cercado facilmente — mas não adie além do quarto turno.")
                tip("arrow.up.and.down.circle.fill",
                    "Um Gorila no topo de uma peça imobiliza o que estiver abaixo. Suba um em um defensor chave para congelá-lo.")
                tip("arrow.triangle.branch",
                    "O Camaleão copia o movimento de qualquer criatura que tocar — e quando sobe na formação, só pode se mover como Gorila.")
                tip("point.topleft.down.curvedto.point.bottomright.up",
                    "O Guepardo pode deslizar por qualquer lado externo da formação. É sua peça mais versátil — vale a pena guardar para finalizar um cerco.")
                tip("hexagon",
                    "Continue contando os lados: observe os lados abertos do seu Leão tanto quanto os do oponente.")
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
            Text("Pronto para Jogar")
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Jogue uma partida guiada contra um bot bem indulgente para praticar o que acabou de aprender, ou entre direto em um jogo real.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                bigButton("Jogar Tutorial", filled: true) {
                    OnboardingState.hasSeenTutorial = true
                    onFinish(true)
                }
                bigButton("Começar a Jogar", filled: false) {
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
