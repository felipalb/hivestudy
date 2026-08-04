---
tipo: codigo
arquivo: HiveEngine/Sources/HiveEngine/MoveGenerator.swift
tags: [hive/codigo]
---

# COD-MoveGenerator (`MoveGenerator.swift`)

Gera as jogadas legais de um estado: colocações + movimentos de peça. Aplica o
gate de [[MEC-Cut Vertex|cut vertex]] antes de levantar e roteia cada bug para
sua travessia em [[COD-Rules]].

- `legalMoves`, `placementCells`, `legalPlacements`, `destinations(for:in:)`
- **É a função que o [[Perft]] enumera** (fronteira da [[Árvore de Jogo]]).
- **Mecânica:** [[MEC-Placement Cells]] · **Testado por:** [[TEST-PlacementTests]], [[TEST-PinningTests]], [[TEST-LadybugTests]], [[TEST-MosquitoTests]]
