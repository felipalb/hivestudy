---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Ladybug (caminho de 3 arestas: sobe-atravessa-desce)

A Joaninha faz **exatamente 3 passos**: dois *em cima* da colmeia (cada um sobre
célula ocupada) e o terceiro *descendo* numa célula vazia adjacente. Nunca
termina em cima; não volta à própria origem. Andando por cima, **não** é gatada
pela liberdade de movimento.

- **Conceito:** [[Caminho de Comprimento Fixo]]
- **Vive em:** [[COD-Rules]] → `ladybugDestinations` (triplo laço `occupiedNeighbors → occupiedNeighbors → emptyNeighbors`)
- **Testada por:** [[TEST-LadybugTests]]
- **Governa:** [[Joaninha]]; copiado pelo [[Mosquito]]

Precisa de ≥2 peças para atravessar (uma só não dá pra "cruzar"). O cut-vertex
de One-Hive ainda se aplica **antes** de levantar.
