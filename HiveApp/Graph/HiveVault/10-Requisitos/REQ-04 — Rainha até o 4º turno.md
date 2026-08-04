---
tipo: requisito
id: REQ-04
status: coberto
tags: [hive/requisito]
---

# REQ-04 — Rainha até o 4º turno

Cada jogador **deve** ter colocado sua Rainha até o 4º turno. Enquanto a Rainha
está na mão, **nenhuma** peça pode se mover.

- **Implementado por:** [[MEC-Placement Cells]] (via `mustPlaceQueen`)
- **Vive em:** [[COD-GameState]] (`mustPlaceQueen`, `queenPlaced`)
- **Verificado por:** [[TEST-PlacementTests]]
- **Governa:** [[Rainha]]

## Critérios de aceite

- No 4º turno sem Rainha → todas as colocações legais são de Rainha.
- Sem Rainha no tabuleiro → `legalPieceMoves` vazio.
