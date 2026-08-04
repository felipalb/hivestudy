# Hive — a native SwiftUI implementation

A complete, fully native iOS implementation of **[Hive](https://ludopedia.com.br/jogo/hive)**, the
tile-laying abstract strategy game by John Yianni. Play against a built-in AI (three difficulties)
or pass-and-play with a friend.

<p align="center">
  <em>Surround the enemy Queen Bee on all six sides to win.</em>
</p>

## What's here

The project is split into a pure game engine and a SwiftUI app, so the tricky rules can be tested
fast without a simulator:

```
hivestudy/
├── HiveEngine/            Swift Package — pure game logic, no UI (unit-tested)
│   ├── Sources/HiveEngine/
│   │   ├── Hex.swift          Axial hex coordinates + gate geometry
│   │   ├── Piece.swift        Bugs, colours, tiles
│   │   ├── Board.swift        Stacks, occupancy, One-Hive connectivity
│   │   ├── Rules.swift        Sliding freedom, beetle height-gate, jumps
│   │   ├── Move.swift         Move / result types
│   │   ├── GameState.swift    Turn flow, placement/queen rules, win detection
│   │   ├── MoveGenerator.swift Legal placements & per-bug moves
│   │   └── AI.swift           Negamax + alpha-beta + heuristic
│   └── Tests/HiveEngineTests/ 47 tests total
│       ├── HiveEngineTests.swift   37 tests (rules, AI, self-play invariants)
│       └── GraphHarnessTests.swift 10 tests (Perft, metamorphic, property-based)
│
└── HiveApp/               The iOS app
    ├── project.yml            XcodeGen spec (generates Hive.xcodeproj)
    ├── Sources/               SwiftUI views + GameController
    └── Graph/HiveVault/       Obsidian traceability vault (QA graph-engineering study)
```

## Build & run

**Requirements:** Xcode 16+ (built with Xcode 26.5 / Swift 6.3), iOS 17+ simulator or device.

### Run the app

```bash
cd HiveApp
xcodegen generate          # regenerates Hive.xcodeproj from project.yml
open Hive.xcodeproj        # then press ⌘R
```

Or straight from the command line:

```bash
cd HiveApp
xcodebuild -scheme Hive -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### Test the engine (fast, no simulator)

```bash
cd HiveEngine
swift test
```

## Features

- **Vs. Computer** with Easy / Medium / Hard AI, or **two-player** hot-seat.
- Choose your colour and toggle the **tournament opening** rule (no Queen on move one).
- Tiles are labelled with the piece's **actual name** (Queen, Spider, Beetle, Grasshopper, Ant),
  each in its own accent colour.
- Tap a tile in your hand to place it, or tap a tile on the board to move it — legal destinations
  light up as pulsing markers. Beetle-climb targets get a ring on the tile itself.
- **Pan & pinch-zoom** the board; a camera auto-frames the hive until you take manual control, with
  a recenter button docked at the right edge.
- Live **queen-surround counters** (e.g. `3/6`) in the status bar — the heart of Hive's tension.
- **Auto-save & resume**: your match is cached after every move, so closing the app never loses it —
  reopen and choose *Continue Game* or *Leave Game*.
- Undo, an in-app **rules reference**, animated moves, and haptic feedback.

## Rules implemented

Base game: **1 Queen Bee, 2 Spiders, 2 Beetles, 3 Grasshoppers, 3 Soldier Ants** per player.

The subtle rules — the ones that make or break a Hive engine — are implemented exactly:

| Rule | Implementation |
|------|----------------|
| **Freedom to move** (sliding) | A ground slide from A→B is legal only when *exactly one* of the two shared "gate" cells is occupied — one gives contact with the hive, the other gives the gap to slip through. |
| **Beetle gate** (height) | A beetle is blocked only when `min(gate heights) > max(source floor, destination floor)`; otherwise it may climb, descend, or slide. A beetle on top pins the tile beneath. |
| **One-Hive** | A ground tile whose removal would split the hive (an articulation point) cannot move at all. |
| **Spider** | Exactly three single slide steps, never revisiting a cell. |
| **Ant** | Any number of slide steps around the perimeter (breadth-first). |
| **Grasshopper** | Jumps in a straight line over ≥1 contiguous tiles to the first empty cell. |
| **Ladybug** | Exactly three steps — up onto the hive, across the top to a second tile, then down into an empty cell. Ends on the ground, never on its own start; not gated while crossing the top. |
| **Mosquito** | On the ground, the union of every distinct bug touching it (never copying another mosquito). Once it has climbed onto the hive, it moves only as a Beetle. |
| **Placement** | New tiles must touch a friendly tile and no enemy tile (with the standard opening exceptions). The Queen must be down by turn 4, and no tile moves until she's placed. |
| **Win / draw** | A queen surrounded on all six sides loses; both at once is a draw. |

**Expansions:** the **Mosquito and Ladybug** are fully implemented and **always in the roster** for
both players in every match (one each). Only the **Pillbug** remains scaffolded in the type system —
it can be placed but has no movement rule yet — and is not part of the roster.

## The AI

`HiveAI` runs iterative-deepening **negamax with alpha-beta pruning** and a strictly zero-sum
heuristic dominated by queen-surrounding (quadratic, so the last couple of sides are urgent), plus a
mobility term. Search runs off the main actor with a time budget so the UI stays responsive.

It plays to **win**, not merely to hinder: it always takes an immediate winning move, scores mates by
distance so it drives to the *fastest* kill, and never throws away a blunder when either queen is
under threat (even on Easy/Medium). It reliably beats random play and finds forced mates-in-one (both
covered by tests). If a human player is ever left with no legal move, the app passes for them so the
opponent can finish.

## 🕸️ Estudo: Graph Engineering aplicado a testes (QA)

> Esta seção documenta um estudo de **engenharia de grafos aplicada a testes**,
> feito sobre este projeto no contexto de um processo seletivo de QA.

**Insight central:** *Hive é um grafo dos dois lados.* O domínio já é teoria dos
grafos — o tabuleiro é um grafo, a regra **One-Hive** é conectividade, o
movimento é travessia e a **IA** é uma árvore de jogo. Logo, testar Hive é
engenharia de grafos tanto nos **algoritmos testados** quanto na **estratégia de
teste**, modelada como grafo. Dois artefatos foram construídos:

### 1. Cofre Obsidian — grafo de rastreabilidade  ·  `HiveApp/Graph/HiveVault/`

**62 notas linkadas** formando um grafo navegável de QA. Abra a **Graph View**
(`Cmd/Ctrl+G`): ela vira uma **matriz de rastreabilidade viva** — um requisito
sem aresta para nenhum teste aparece como nó isolado, ou seja, **lacuna de
cobertura visível**.

| Tipo de nó | Pasta | Papel |
|-----------|-------|-------|
| Central | `00-Central` | índices, **Estratégia de Teste**, **Matriz de Rastreabilidade** |
| Requisito | `10-Requisitos` | *o que* o jogo garante (REQ-01…07) |
| Mecânica | `20-Mecanicas` | *como* cada regra é implementada (o algoritmo de grafo) |
| Peça | `30-Pecas` | os 8 bugs, ligando peça → mecânica → teste |
| Conceito de grafo | `40-Conceitos-Grafo` | a teoria (BFS, cut vertex, Perft, MBT, metamórfico…) |
| Teste | `50-Testes` | os suites reais de `HiveEngineTests` |
| Código | `60-Codigo` | os arquivos do `HiveEngine` |

Arestas: `Requisito →verificado por→ Teste`, `Mecânica →usa→ Conceito de grafo`,
`Peça →governada por→ Mecânica`, etc.

### 2. Harness de teste  ·  `HiveEngine/Tests/HiveEngineTests/GraphHarnessTests.swift`

**10 testes** que materializam as técnicas do cofre e fecham lacunas da matriz.
Rodam em ~3 s; a suíte completa fica **47/47 verde**.

| Suite | Técnica | O que garante |
|-------|---------|---------------|
| `PerftTests` | **Perft** (enumeração da árvore de jogo) | golden numbers `perft(1)=5`, `perft(2)=150`, `perft(3)=2220` + divide-perft estrutural — um número errado denuncia bug no gerador de movimentos |
| `MetamorphicTests` | **Teste metamórfico** | rotação 60° comuta com o BFS da Formiga e o deslize (a rotação tem período 6) |
| `PropertyInvariantTests` | **Teste por propriedades** (fuzz) | One-Hive nunca quebra, **cut-vertex ⇒ 0 destinos**, `.pass` é exclusivo, `apply` determinístico, round-trip levantar/repor |

```bash
cd HiveEngine
swift test --filter "PerftTests|MetamorphicTests|PropertyInvariantTests"
```

### Mapeamento grafo ↔ código

| Conceito de grafo | Onde vive | Peça/Regra |
|-------------------|-----------|------------|
| Componentes conexos (DFS) | `Board.connectedComponentCount` | One-Hive |
| Ponto de articulação (cut vertex) | `Board.isCutVertex` | peça que trava |
| Busca em largura (BFS) | `Rules.antReachable` | Formiga |
| Busca em profundidade limitada | `Rules.exactSlideDestinations` | Aranha |
| Caminho de comprimento fixo | `Rules.ladybugDestinations` | Joaninha |
| Raio em linha reta | `Rules.grasshopperDestinations` | Gafanhoto |
| Árvore de jogo | `AI.swift` (negamax) / `Perft` | a IA e o Perft |

### Técnicas & vocabulário do estudo

`graph coverage criteria` (Ammann & Offutt) · `model-based testing` ·
`metamorphic testing` · `property-based testing` · `perft` ·
`articulation points / cut vertices` · `connected components` ·
`differential testing` · `traceability matrix`. Próximos passos anotados na
**Matriz de Rastreabilidade**: MBT com critérios de cobertura de grafo,
reflexão como 2ª relação metamórfica, e teste isolado de destinos da Rainha.

## Notes

- `Hive.xcodeproj` is generated by [XcodeGen](https://github.com/yonyz/XcodeGen) from `project.yml`;
  edit the spec, not the project, and re-run `xcodegen generate`.
- Launching with the environment variable `HIVE_DEMO=1` seeds an illustrative mid-game position
  (used for screenshots).
