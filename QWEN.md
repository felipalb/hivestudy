# Hive — Qwen Code Context

## Project Overview

A native iOS implementation of **Hive**, the tile-laying abstract strategy game by John Yianni. Two-player or vs. AI (three difficulties). Built with SwiftUI + a pure-Swift game engine.

**Architecture:** two-module split —

| Module | Purpose | Tech |
|--------|---------|------|
| `HiveEngine/` | Pure game logic, no UI — value types, fully unit-tested | Swift Package (swift-tools 6.0), Swift Testing |
| `HiveApp/` | SwiftUI iOS app | XcodeGen (`project.yml` → `Hive.xcodeproj`) |

Bundle ID: `com.hivestudy.Hive` · Deployment target: iOS 17 · Built with Xcode 26.5 / Swift 6.3.

## Build & Test Commands

```bash
# Engine tests (fast, no simulator) — run after ANY engine change
cd HiveEngine && swift test

# Filter graph-harness tests only
cd HiveEngine && swift test --filter "PerftTests|MetamorphicTests|PropertyInvariantTests"

# Regenerate Xcode project (after adding/removing files)
cd HiveApp && xcodegen generate

# Build the app
cd HiveApp && xcodebuild -scheme Hive -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Seed a demo mid-game position (for screenshots)
SIMCTL_CHILD_HIVE_DEMO=1 xcrun simctl launch booted com.hivestudy.Hive
```

## Engine Source Map

```
HiveEngine/Sources/HiveEngine/
  Hex.swift           Axial hex coordinates + gate geometry
  Piece.swift         Bug/PlayerColor/Piece (Bug.displayName, Bug.tileName, Bug.letter)
  Board.swift         Stacks, occupancy, One-Hive connectivity (Codable)
  Rules.swift         Sliding freedom, beetle gate, jumps, mosquito copy-ability
  Move.swift          Move / GameResult
  GameState.swift     Turn flow, placement/queen rules, win detection (Codable)
  MoveGenerator.swift Legal placements & per-bug moves
  AI.swift            Negamax + alpha-beta + heuristic (incl. megaEasy tutorial tier)
```

## App Source Map

```
HiveApp/Sources/
  HiveApp.swift           @main App
  ContentView.swift       Root screen, top bar, trays, overlays (onboarding, game over, resume)
  BoardView.swift         Zoomable/pannable board, camera controls, auto-fit
  TileView.swift          One hexagon tile (icon above name, tinted in bug's accent)
  BugIcon.swift           Hand-drawn Shape glyph per bug (BugIcon → GlyphShape per bug)
  HandTrayView.swift      A player's remaining tiles (dynamic sizing via GeometryReader)
  NewGameSheet.swift      GameMenuSheet (setup) + RulesView (pushed)
  OnboardingView.swift    First-launch tutorial overlay
  GameController.swift    @Observable @MainActor owner of state, AI, persistence
  GamePersistence.swift   SavedGame + UserDefaults cache
  Theme.swift             Palette (reads asset-catalog colours) + per-bug accent
```

## Conventions & Gotchas

- **XcodeGen owns the project.** Edit `HiveApp/project.yml`, never `Hive.xcodeproj` directly. Sources are globbed from `Sources/` and `Resources/`; new files are picked up on next `xcodegen generate`.
- **Engine stays UI-free and pure.** No SwiftUI/UIKit imports. Value semantics only — the AI copies states cheaply, the app snapshots for undo/persistence.
- **SourceKit lies about `HiveEngine`.** In-editor "No such module" errors are indexer noise. The real check is `xcodebuild` / `swift test`.
- **Big SwiftUI expressions type-check slowly.** If the compiler says "unable to type-check this expression in reasonable time", split into smaller sub-expressions / computed properties.
- **Colours live in the asset catalog** (`HiveApp/Resources/Assets.xcassets/`), never as RGB literals. `Theme.swift` only names them. Add a `.colorset` for any new colour.
- **`Hex` is a dictionary key** in `Board.stacks`; JSON round-trips as array of key/value pairs — this is what persistence relies on.
- **Expansion roster is fixed:** Mosquito + Ladybug always on for both players. Pillbug is scaffolded in the enum but has no movement rules and is not in the roster.
- **AI difficulty tiers:** `megaEasy` (depth 1, 60% blunder — vestigial, hidden from UI), `easy` (depth 1, 25% blunder), `medium` (depth 2, no blunder), `hard` (depth 4, no blunder). Keep `medium` at depth 2 — `aiBeatsRandomPlayer` tests against it.
- **Two sheets must never stack.** Menu sheet is on ContentView root; How to Play sheet is on BoardView. RulesView carries no NavigationStack of its own.

## Key Systems

| System | Key Detail |
|--------|-----------|
| **Tile visuals** | `BugIcon` Shape glyphs (not SF Symbols) above `Bug.tileName`, tinted with `accent(_:on:)`. No background plaque. Even-odd fill for cut-outs. |
| **Hand tray** | Dynamic sizing via `GeometryReader`. Two branches: plain HStack (fits) vs. ScrollView with edge fade (6-type hand on phone). Never put the fits-case in a ScrollView — it clips selection effects. |
| **Camera** | Docked mid-right. Buttons: Play Tutorial, Recenter, How to Play. Board auto-fits until user adjusts. |
| **Long-press inspect** | 0.4s gesture on board tiles or hand chips → `PieceMoveInfoOverlay`. Blurb sourced from `RulesView.bugs`. |
| **Tutorial** | `TutorialView` overlay (not an AI game). 9 scripted steps via `TutorialController`/`TutorialScript`. Each drill loads its own position. Final drill wins by surrounding Black's Queen. |
| **Onboarding** | First-launch only (`OnboardingState.hasSeenTutorial`). Paged walkthrough ending with "Play Tutorial" or "Start Playing". |
| **Persistence** | Cached after every ply via `GamePersistence` (JSON in UserDefaults, key `hive.savedGame.v1`). Cleared on game end, newGame, leaveMatch. Resume overlay shown at launch if saved game exists. |
| **Auto-pass** | If a human's only legal move is `.pass`, app passes automatically after a short beat. |

## Testing

47 tests total in `HiveEngine/Tests/HiveEngineTests/`:

| Suite | Count | Coverage |
|-------|-------|---------|
| `HiveEngineTests` | 37 | Rules, connectivity, win detection, self-play invariants, Mosquito, Ladybug, tutorial scenarios, AI |
| `GraphHarnessTests` | 10 | Perft (golden numbers), metamorphic (60° rotation), property-based invariants (One-Hive, cut-vertex, determinism) |

## Graph Engineering Study (QA)

`HiveApp/Graph/HiveVault/` — an Obsidian vault with 62 linked notes forming a QA traceability graph. Open Graph View (`Cmd+G`) as a living traceability matrix: isolated nodes = coverage gaps.

Node types: Requirements → Mechanics → Pieces → Graph Concepts → Tests → Code. Edges trace `requirement →verified by→ test`, `mechanism →uses→ graph concept`, etc.

## Environment Variable

- `HIVE_DEMO=1` — seeds an illustrative mid-game position (for screenshots).
