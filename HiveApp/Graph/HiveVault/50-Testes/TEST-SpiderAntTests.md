---
tipo: teste
suite: SpiderAntTests
tags: [hive/teste]
---

# TEST-SpiderAntTests

- `spiderWalksExactlyThreeSteps` — Aranha: destinos a exatamente 3 passos.
- `antReachesWholePerimeter` — Formiga alcança todo o anel (7 células), menos a origem.
- `spiderIsSubsetOfAnt` — **relação metamórfica:** Aranha ⊆ Formiga.
- `oneStepMatchesGroundSlideSteps` — passo unitário == `groundSlideSteps`.

**Peças:** [[Aranha]], [[Formiga]] · **Mecânicas:** [[MEC-Spider Walk (DFS)]], [[MEC-Ant Reachable (BFS)]]
· **Conceitos:** [[Busca em Largura (BFS)]], [[Caminho de Comprimento Fixo]], [[Teste Metamórfico]]
