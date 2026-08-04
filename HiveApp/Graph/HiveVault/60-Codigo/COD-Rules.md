---
tipo: codigo
arquivo: HiveEngine/Sources/HiveEngine/Rules.swift
tags: [hive/codigo]
---

# COD-Rules (`Rules.swift`)

Primitivas de movimento — as **travessias de grafo** por peça. Espera a peça já
levantada do `board`.

- `canGroundSlide` / `groundSlideSteps` → [[MEC-Ground Slide]]
- `antReachable` (BFS) → [[MEC-Ant Reachable (BFS)]]
- `exactSlideDestinations` (DFS) → [[MEC-Spider Walk (DFS)]]
- `beetleDestinations` → [[MEC-Beetle Gate]]
- `grasshopperDestinations` → [[MEC-Grasshopper Jump]]
- `ladybugDestinations` → [[MEC-Ladybug]]
- `mosquitoGroundDestinations` → [[MEC-Mosquito Copy]]

**Testado por:** [[TEST-SlideTests]], [[TEST-SpiderAntTests]], [[TEST-BeetleTests]],
[[TEST-GrasshopperTests]], [[TEST-LadybugTests]], [[TEST-MosquitoTests]]
