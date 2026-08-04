---
tipo: codigo
arquivo: HiveEngine/Sources/HiveEngine/GameState.swift
tags: [hive/codigo]
---

# COD-GameState (`GameState.swift`)

Estado completo e **value type** (cópia barata → a IA busca e o app desfaz).
Fluxo de turno, regra da Rainha, detecção de vitória.

- `apply`/`applying` — transição (aresta da [[Árvore de Jogo]]).
- `mustPlaceQueen`, `queenPlaced` → [[REQ-04 — Rainha até o 4º turno]]
- `queenSurrounded`, `evaluateResult` → [[REQ-05 — Vitória por Cerco]], [[REQ-06 — Empate]]
- É `Equatable` → viabiliza o **round-trip** de [[Teste Metamórfico]].
- **Testado por:** [[TEST-WinTests]], [[TEST-PlacementTests]]
