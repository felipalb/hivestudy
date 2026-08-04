---
tipo: codigo
arquivo: HiveEngine/Sources/HiveEngine/Board.swift
tags: [hive/codigo]
---

# COD-Board (`Board.swift`)

A superfície de jogo (pilhas por célula) + os **algoritmos de grafo de
conectividade**. É o arquivo mais "grafo" do projeto.

- `connectedComponentCount(excluding:)` — DFS iterativa, early-exit.
- `isConnected()`, `isCutVertex(_:)` — [[Componentes Conexos]], [[Ponto de Articulação]].
- `occupiedNeighbors`, `emptyNeighbors`, `touchesHive` — vizinhança do grafo.
- **Mecânicas:** [[MEC-Conectividade]], [[MEC-Cut Vertex]] · **Testado por:** [[TEST-ConnectivityTests]]
