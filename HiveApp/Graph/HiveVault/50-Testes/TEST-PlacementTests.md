---
tipo: teste
suite: PlacementTests
tags: [hive/teste]
---

# TEST-PlacementTests

- `firstMoveGoesToOrigin` — 1ª jogada só na origem; 5 bugs-base colocáveis.
- `secondPlayerPlacesAdjacentToOpponent` — 2º jogador nos 6 lados.
- `cannotPlaceNextToEnemyAfterOpening` — toca amigo, não toca inimigo.
- `queenMustBePlacedByFourthTurn` — 4º turno força Rainha; sem Rainha, nada move.

**Cobre:** [[REQ-03 — Colocação de Peças]], [[REQ-04 — Rainha até o 4º turno]]
· **Mecânica:** [[MEC-Placement Cells]] · **Código:** [[COD-MoveGenerator]], [[COD-GameState]]
