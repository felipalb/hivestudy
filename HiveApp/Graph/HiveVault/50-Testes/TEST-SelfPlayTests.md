---
tipo: teste
suite: SelfPlayTests
tags: [hive/teste, hive/harness]
---

# TEST-SelfPlayTests

- `randomGamesKeepTheHiveConnected` — 20 partidas com RNG semeada; a cada ply
  com ≥2 peças, `board.isConnected()`. Também garante `legalMoves` nunca vazio.

Este é o **embrião de [[Teste por Propriedades]]** no projeto — o harness
expande as invariantes (round-trip, simetria, cut-vertex⇒0-destinos).

**Cobre (parcial):** [[REQ-01 — One-Hive]], [[REQ-07 — Passe Obrigatório]] · **Conceito:** [[Teste por Propriedades]]
