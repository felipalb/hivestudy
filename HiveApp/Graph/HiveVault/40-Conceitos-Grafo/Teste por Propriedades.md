---
tipo: conceito
tags: [hive/conceito, hive/harness]
---

# Teste por Propriedades (property-based)

Em vez de "entrada → saída esperada", afirma **propriedades que valem sempre** e
gera muitas entradas aleatórias (fuzz) para tentar violá-las.

## Invariantes do Hive (o "oráculo" do fuzz)

- **Conectividade:** após qualquer jogada legal, `board.isConnected()`.
- **Cut vertex ⇒ 0 destinos:** peça de chão que é ponto de articulação não move.
- **Legalidade:** `legalMoves` nunca vazio numa partida em andamento (≥ `.pass`).
- **Determinismo:** mesmo estado + mesma jogada ⇒ mesmo estado resultante.
- **Round-trip:** aplicar+reverter = identidade ([[Teste Metamórfico]]).

O `SelfPlayTests` já faz isso para a conectividade com RNG semeada
([[TEST-SelfPlayTests]]) — o harness **expande** o rol de invariantes.
