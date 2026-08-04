---
tipo: conceito
tags: [hive/conceito]
---

# Ponto de Articulação (cut vertex)

Vértice cuja remoção **aumenta** o número de componentes conexos — desconecta o
grafo. Numa ponte de grafo, é o vértice "gargalo".

- **Algoritmo clássico:** Tarjan (DFS, tempos de descoberta + low-link) em O(V+E).
- **No Hive:** peça de chão que é cut vertex **não pode mover** → [[MEC-Cut Vertex]].
- **Testar:** meio da linha é cut vertex; ponta não; peça empilhada nunca é.
  Excelente alvo de **differential testing**: Tarjan vs. recontagem ingênua.
- Ver [[TEST-ConnectivityTests]], [[REQ-01 — One-Hive]].
