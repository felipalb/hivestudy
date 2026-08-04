---
tipo: teste
suite: GraphHarnessTests
arquivo: HiveEngine/Tests/HiveEngineTests/GraphHarnessTests.swift
tags: [hive/teste, hive/harness]
---

# TEST-GraphHarness ⚙️

O **harness de graph engineering** — 10 testes novos que materializam as
técnicas do cofre e fecham lacunas da [[Matriz de Rastreabilidade]]. Roda em
~3s. Todos verdes contra a engine real.

## `PerftTests` → [[Perft]]

- `depth1CountsOpeningMoves` — perft(1) == `legalMoves().count` == 5.
- `depth2CountsSecondPly` — perft(2) == 150.
- `dividePerftSumsToTotal` — invariante estrutural: divide-perft soma ao total (prof. 2 e 3).
- `goldenRegressionBaseline` — **golden numbers** travados: 5 / 150 / **2220** (base game).

## `MetamorphicTests` → [[Teste Metamórfico]]

- `antReachabilityIsRotationInvariant` — rotação 60° comuta com o BFS da [[Formiga]].
- `groundSlideStepsAreRotationInvariant` — idem para o deslize de 1 passo.
- `rotationHasPeriodSix` — auto-checagem: a rotação tem período 6 (é bijeção).

## `PropertyInvariantTests` → [[Teste por Propriedades]]

- `invariantsHoldThroughoutRandomGames` — 30 partidas semeadas; a cada ply:
  One-Hive ([[REQ-01 — One-Hive]]), `.pass` exclusivo ([[REQ-07 — Passe Obrigatório]]),
  **cut-vertex ⇒ 0 destinos** ([[MEC-Cut Vertex]]), e determinismo do `apply`.
- `liftAndReplaceIsIdentity` — round-trip levantar/repor peça == board idêntico ([[COD-Board]]).
- `generatedMovesAreAllLegal` — gerador ↔ validador: todo movimento gerado é legal.

## Como rodar

```bash
cd HiveEngine
swift test --filter "PerftTests|MetamorphicTests|PropertyInvariantTests"
```
