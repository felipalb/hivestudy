---
tipo: conceito
tags: [hive/conceito]
---

# Componentes Conexos

Partição de um grafo em subgrafos maximais onde todo par de vértices está ligado
por um caminho. Um grafo é **conexo** se tem exatamente 1 componente.

- **Como calcular:** BFS/DFS marcando visitados; cada nova semente = novo componente.
- **No Hive:** o footprint da colmeia deve ter 1 componente → [[MEC-Conectividade]].
- **Testar:** montar tabuleiros com 1, 2 e 3 componentes e conferir a contagem;
  differential vs. union-find. Ver [[TEST-ConnectivityTests]].
