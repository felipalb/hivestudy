---
tipo: codigo
arquivo: HiveEngine/Sources/HiveEngine/Hex.swift
tags: [hive/codigo]
---

# COD-Hex (`Hex.swift`)

Coordenadas axiais do grid hexagonal. Define vizinhança (as 6 direções),
**portões** de uma aresta e distância. É o vocabulário de nós/arestas do grafo.

- `neighbors`, `gates(_:)`, `direction(to:)`, `distance(to:)`
- **Testado por:** [[TEST-HexTests]]
- **Base de:** [[MEC-Ground Slide]], [[MEC-Conectividade]]
