---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Ground Slide (deslize de um passo)

Primitiva de deslizamento por uma aresta: destino vazio **e** exatamente um dos
dois portões ocupado ([[REQ-02 — Liberdade de Movimento]]). É a aresta base do
grafo de movimento sobre o qual BFS/DFS rodam.

- **Implementa:** [[REQ-02 — Liberdade de Movimento]]
- **Vive em:** [[COD-Rules]] → `canGroundSlide`, `groundSlideSteps`
- **Testada por:** [[TEST-SlideTests]]
- **Base de:** [[MEC-Ant Reachable (BFS)]], [[MEC-Spider Walk (DFS)]]
- **Governa:** [[Rainha]] (um passo)

`groundSlideSteps` devolve as até-6 arestas válidas a partir de uma célula. É a
função de vizinhança do grafo de deslize.
