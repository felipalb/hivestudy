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
│   └── Tests/HiveEngineTests/ 27 tests (rules, AI, self-play invariants)
│
└── HiveApp/               The iOS app
    ├── project.yml            XcodeGen spec (generates Hive.xcodeproj)
    └── Sources/               SwiftUI views + GameController
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
| **Placement** | New tiles must touch a friendly tile and no enemy tile (with the standard opening exceptions). The Queen must be down by turn 4, and no tile moves until she's placed. |
| **Win / draw** | A queen surrounded on all six sides loses; both at once is a draw. |

The three classic expansions (**Mosquito, Ladybug, Pillbug**) are scaffolded in the type system for
a future update; the base game is fully playable.

## The AI

`HiveAI` runs iterative-deepening **negamax with alpha-beta pruning** and a strictly zero-sum
heuristic dominated by queen-surrounding (quadratic, so the last couple of sides are urgent), plus a
mobility term. Search runs off the main actor with a time budget so the UI stays responsive.

It plays to **win**, not merely to hinder: it always takes an immediate winning move, scores mates by
distance so it drives to the *fastest* kill, and never throws away a blunder when either queen is
under threat (even on Easy/Medium). It reliably beats random play and finds forced mates-in-one (both
covered by tests). If a human player is ever left with no legal move, the app passes for them so the
opponent can finish.

## Notes

- `Hive.xcodeproj` is generated by [XcodeGen](https://github.com/yonyz/XcodeGen) from `project.yml`;
  edit the spec, not the project, and re-run `xcodegen generate`.
- Launching with the environment variable `HIVE_DEMO=1` seeds an illustrative mid-game position
  (used for screenshots).
