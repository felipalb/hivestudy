---
tipo: teste
suite: HexTests
tags: [hive/teste]
---

# TEST-HexTests

Geometria hexagonal — a base de tudo. Em [[COD-Hex]].

- `gatesAreTheTwoSharedNeighbors` — os portões de uma aresta são os 2 vizinhos comuns.
- `neighborRoundTrip` — `direction(to: neighbor(d)) == d` para as 6 direções.

**Cobre:** fundação de [[REQ-02 — Liberdade de Movimento]] (portões).
