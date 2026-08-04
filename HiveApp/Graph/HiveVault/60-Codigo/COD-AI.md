---
tipo: codigo
arquivo: HiveEngine/Sources/HiveEngine/AI.swift
tags: [hive/codigo]
---

# COD-AI (`AI.swift`)

Negamax + alpha-beta com aprofundamento iterativo sobre a [[Árvore de Jogo]].
Heurística dominada pelo cerco da Rainha (quadrático) + mobilidade.

- Mate-distance scoring (`winScore - ply`) → busca o mate mais rápido.
- **Conceito:** [[Árvore de Jogo]] · **Testado por:** [[TEST-AITests]]
- **Ligação com QA:** a mesma travessia, contando nós em vez de avaliar, é o [[Perft]].
