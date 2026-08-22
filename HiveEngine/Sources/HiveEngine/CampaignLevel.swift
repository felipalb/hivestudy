import Foundation

/// One entry in a player's starting hand for a match or campaign level.
public struct RosterEntry: Sendable, Equatable, Codable {
    public let bug: Bug
    public let count: Int

    public init(bug: Bug, count: Int) {
        self.bug = bug
        self.count = count
    }
}

/// Represents a progressive challenge in the Campaign ("Jornada da Colmeia").
public struct CampaignLevel: Sendable, Equatable, Identifiable, Codable {
    public let id: Int
    public let chapterNumber: Int
    public let title: String
    public let subtitle: String
    public let narrative: String
    public let tip: String
    public let botDifficulty: HiveAI.Difficulty
    public let botDifficultyName: String
    public let targetParTurns: Int
    public let isPuzzleScenario: Bool
    public let focusBug: Bug

    public init(
        id: Int,
        chapterNumber: Int,
        title: String,
        subtitle: String,
        narrative: String,
        tip: String,
        botDifficulty: HiveAI.Difficulty,
        botDifficultyName: String,
        targetParTurns: Int,
        isPuzzleScenario: Bool = true,
        focusBug: Bug = .queen
    ) {
        self.id = id
        self.chapterNumber = chapterNumber
        self.title = title
        self.subtitle = subtitle
        self.narrative = narrative
        self.tip = tip
        self.botDifficulty = botDifficulty
        self.botDifficultyName = botDifficultyName
        self.targetParTurns = targetParTurns
        self.isPuzzleScenario = isPuzzleScenario
        self.focusBug = focusBug
    }

    /// Creates an initial GameState tailored for this campaign challenge.
    public func createInitialState() -> GameState {
        switch id {
        case 1:
            return CampaignLevel.level1State()
        case 2:
            return CampaignLevel.level2State()
        case 3:
            return CampaignLevel.level3State()
        case 4:
            return CampaignLevel.level4State()
        case 5:
            return CampaignLevel.level5State()
        case 6:
            return CampaignLevel.level6State()
        default:
            return GameState(config: GameConfig(tournamentOpening: false, expansions: [.mosquito, .ladybug]))
        }
    }

    // MARK: - Level Initial States

    /// Level 1: "O Cerco da Formiga" - 2 turns to victory
    private static func level1State() -> GameState {
        var b = Board()
        var idCounter = 1

        func place(_ hex: Hex, _ bug: Bug, _ color: PlayerColor) {
            b.push(Piece(id: idCounter, bug: bug, color: color), at: hex)
            idCounter += 1
        }

        place(Hex(0, 0), .queen, .black)
        place(Hex(1, 0), .queen, .white)
        place(Hex(1, -1), .ant, .black)
        place(Hex(0, -1), .spider, .white)
        place(Hex(-1, 0), .beetle, .black)
        place(Hex(2, -1), .ant, .white)
        place(Hex(2, 0), .ant, .white)
        place(Hex(0, -2), .grasshopper, .black)

        return GameState(
            board: b,
            current: .white,
            unplaced: [],
            movesMade: [.white: 3, .black: 3]
        )
    }

    /// Level 2: "A Rota da Aranha" - 1 turn 3-step route
    private static func level2State() -> GameState {
        var b = Board()
        var idCounter = 1

        func place(_ hex: Hex, _ bug: Bug, _ color: PlayerColor) {
            b.push(Piece(id: idCounter, bug: bug, color: color), at: hex)
            idCounter += 1
        }

        place(Hex(1, 0), .queen, .black)
        place(Hex(0, 0), .queen, .white)
        place(Hex(0, 1), .ant, .white)
        place(Hex(1, 1), .beetle, .black)
        place(Hex(2, 0), .ant, .black)
        place(Hex(2, -1), .grasshopper, .black)
        place(Hex(-1, 1), .spider, .white)

        return GameState(
            board: b,
            current: .white,
            unplaced: [],
            movesMade: [.white: 3, .black: 3]
        )
    }

    /// Level 3: "O Salto do Gafanhoto" - 1 turn line jump
    private static func level3State() -> GameState {
        var b = Board()
        var idCounter = 1

        func place(_ hex: Hex, _ bug: Bug, _ color: PlayerColor) {
            b.push(Piece(id: idCounter, bug: bug, color: color), at: hex)
            idCounter += 1
        }

        place(Hex(0, 0), .queen, .black)
        place(Hex(1, -1), .queen, .white)
        place(Hex(0, -1), .ant, .black)
        place(Hex(-1, 0), .spider, .black)
        place(Hex(-1, 1), .ant, .white)
        place(Hex(0, 1), .grasshopper, .black)
        place(Hex(-2, 0), .beetle, .white)
        place(Hex(-3, 0), .grasshopper, .white)

        return GameState(
            board: b,
            current: .white,
            unplaced: [],
            movesMade: [.white: 4, .black: 4]
        )
    }

    /// Level 4: "O Bloqueio do Besouro" - Decisive Beetle victory
    private static func level4State() -> GameState {
        var b = Board()
        var idCounter = 1

        func place(_ hex: Hex, _ bug: Bug, _ color: PlayerColor) {
            b.push(Piece(id: idCounter, bug: bug, color: color), at: hex)
            idCounter += 1
        }

        place(Hex(0, 0), .queen, .black)
        place(Hex(1, 0), .queen, .white)
        place(Hex(1, -1), .ant, .black)
        place(Hex(0, -1), .ant, .white)
        place(Hex(-1, 0), .spider, .black)
        place(Hex(-1, 1), .grasshopper, .white)
        place(Hex(1, 1), .beetle, .white)
        place(Hex(-1, 2), .ant, .white)

        return GameState(
            board: b,
            current: .white,
            unplaced: [],
            movesMade: [.white: 4, .black: 4]
        )
    }

    /// Level 5: "O Voo da Joaninha" - 1 turn climb 2 drop 1
    private static func level5State() -> GameState {
        var b = Board()
        var idCounter = 1

        func place(_ hex: Hex, _ bug: Bug, _ color: PlayerColor) {
            b.push(Piece(id: idCounter, bug: bug, color: color), at: hex)
            idCounter += 1
        }

        place(Hex(0, 0), .queen, .black)
        place(Hex(1, 0), .queen, .white)
        place(Hex(1, -1), .beetle, .black)
        place(Hex(0, -1), .ant, .black)
        place(Hex(-1, 0), .spider, .black)
        place(Hex(-1, 1), .grasshopper, .white)
        place(Hex(-2, 1), .ladybug, .white)

        return GameState(
            board: b,
            current: .white,
            unplaced: [],
            movesMade: [.white: 3, .black: 3],
            config: GameConfig(tournamentOpening: false, expansions: [.ladybug])
        )
    }

    /// Level 6: "A Grande Batalha da Colmeia" - Full Match vs Didactic AI
    private static func level6State() -> GameState {
        GameState(config: GameConfig(tournamentOpening: false, expansions: [.mosquito, .ladybug]))
    }

    // MARK: - Pre-configured 6 Chapters

    public static let allLevels: [CampaignLevel] = [
        CampaignLevel(
            id: 1,
            chapterNumber: 1,
            title: "O Cerco da Formiga",
            subtitle: "Deslize pelo Perímetro",
            narrative: "A Rainha adversária já está encurralada em 4 dos seus 6 lados. Comande suas Formigas Soldado velozes para deslizar pelo perímetro e fechar os 2 espaços restantes!",
            tip: "A Formiga pode percorrer toda a colmeia livremente. Deslize-a até uma das casas vazias ao redor da Rainha preta.",
            botDifficulty: .didactic,
            botDifficultyName: "Didático",
            targetParTurns: 2,
            isPuzzleScenario: true,
            focusBug: .ant
        ),
        CampaignLevel(
            id: 2,
            chapterNumber: 2,
            title: "A Rota da Aranha",
            subtitle: "Exatamente Três Passos",
            narrative: "A Rainha adversária possui apenas uma saída aberta. Calcule a rota exata de 3 passos da sua Aranha contornando a colmeia para aplicar o xeque-mate.",
            tip: "A Aranha precisa dar exatamente 3 passos ao longo da borda: 1, 2, 3 até a casa destacada.",
            botDifficulty: .didactic,
            botDifficultyName: "Didático",
            targetParTurns: 1,
            isPuzzleScenario: true,
            focusBug: .spider
        ),
        CampaignLevel(
            id: 3,
            chapterNumber: 3,
            title: "O Salto nos Campos",
            subtitle: "Gafanhoto em Linha Reta",
            narrative: "A Rainha inimiga se escondeu atrás de uma fileira densa de peças. Use o Gafanhoto para saltar sobre a muralha inteira e cravar o ponto decisivo.",
            tip: "Gafanhotos saltam em linha reta sobre as peças até a primeira casa vaga do outro lado.",
            botDifficulty: .didactic,
            botDifficultyName: "Didático",
            targetParTurns: 1,
            isPuzzleScenario: true,
            focusBug: .grasshopper
        ),
        CampaignLevel(
            id: 4,
            chapterNumber: 4,
            title: "O Peso do Besouro",
            subtitle: "Avanço e Cerco Implacável",
            narrative: "A Rainha adversária está encurralada em 5 lados, restando apenas um espaço. Avance com seu Besouro para ocupar a última casa aberta e garantir a vitória imediata!",
            tip: "Mova o Besouro 1 passo para a casa vazia ao lado da Rainha adversária ou suba em uma peça para dominar o espaço.",
            botDifficulty: .didactic,
            botDifficultyName: "Didático",
            targetParTurns: 1,
            isPuzzleScenario: true,
            focusBug: .beetle
        ),
        CampaignLevel(
            id: 5,
            chapterNumber: 5,
            title: "O Voo da Joaninha",
            subtitle: "Dois por Cima, Um para Baixo",
            narrative: "A Rainha adversária está protegida em um bolsão estreito inacessível pelo chão. Suba com a Joaninha e desça direto no bolsão de vitória.",
            tip: "A Joaninha escala duas peças no topo da colmeia e desce no terceiro passo em uma casa vazia.",
            botDifficulty: .didactic,
            botDifficultyName: "Didático",
            targetParTurns: 1,
            isPuzzleScenario: true,
            focusBug: .ladybug
        ),
        CampaignLevel(
            id: 6,
            chapterNumber: 6,
            title: "A Grande Batalha",
            subtitle: "Partida Real com Dicas do Mestre",
            narrative: "Você dominou as principais táticas do Hive! Agora comande seu exército completo em uma partida real. Use o botão de Dica sempre que quiser sugestões estratégicas.",
            tip: "Use o botão 💡 Dica no topo para receber conselhos táticos sempre que precisar de orientação.",
            botDifficulty: .didactic,
            botDifficultyName: "Didático",
            targetParTurns: 16,
            isPuzzleScenario: false,
            focusBug: .queen
        )
    ]
}
