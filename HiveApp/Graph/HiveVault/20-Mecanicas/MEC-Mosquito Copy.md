---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Mosquito Copy (união das habilidades vizinhas)

No chão, o Mosquito move-se como a **união** dos tipos distintos de bug que o
tocam — cada um calculado como se ele *fosse* aquele bug. Nunca copia outro
mosquito. Uma vez **em cima** da colmeia (só possível tendo copiado um Besouro),
passa a se mover **apenas** como Besouro.

- **Vive em:** [[COD-Rules]] → `mosquitoGroundDestinations`; roteado em [[COD-MoveGenerator]]
- **Testada por:** [[TEST-MosquitoTests]]
- **Governa:** [[Mosquito]]
- **Depende de:** [[MEC-Beetle Gate]], [[MEC-Ant Reachable (BFS)]], [[MEC-Spider Walk (DFS)]], [[MEC-Grasshopper Jump]], [[MEC-Ladybug]], [[MEC-Ground Slide]]

> Bug real pego no desenvolvimento: a checagem "está em cima?" tem que usar a
> altura **após levantar** (`lifted.height`), não a do tabuleiro original.
> Coberto por `atopHiveMosquitoMovesOnlyAsBeetle`.
