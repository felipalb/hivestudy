---
tipo: conceito
tags: [hive/conceito]
---

# Árvore de Jogo (game tree)

Grafo dirigido onde nós são estados e arestas são jogadas legais. A raiz é a
posição atual; folhas são estados terminais (ou o limite de profundidade).

- **No Hive:** a IA ([[COD-AI]]) faz negamax + alpha-beta sobre essa árvore.
- **Enumerar a árvore = [[Perft]]** (conta nós/folhas a profundidade N).
- **Testar:** contagem de nós conhecida por posição; a IA nunca devolve jogada
  ilegal; acha xeque-mate em 1. Ver [[TEST-AITests]].
