---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Ant Reachable (BFS)

A Formiga alcança **toda** célula acessível por qualquer número de deslizes ao
redor da colmeia. É uma **busca em largura** sobre o grafo de
[[MEC-Ground Slide|deslize]].

- **Conceito:** [[Busca em Largura (BFS)]]
- **Vive em:** [[COD-Rules]] → `antReachable(on:from:)`
- **Testada por:** [[TEST-SpiderAntTests]]
- **Governa:** [[Formiga]]

```swift
static func antReachable(on board: Board, from start: Hex) -> Set<Hex>
```

Propriedade testável útil: destinos da [[Aranha]] (3 passos) ⊆ destinos da
Formiga (ver `spiderIsSubsetOfAnt`). Boa relação para
[[Teste por Propriedades]].
