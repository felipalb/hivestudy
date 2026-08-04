---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Placement Cells (onde colocar / geração de jogadas)

Calcula as células legais de colocação (toca amigo, não toca inimigo, com as
exceções de abertura) e monta a lista de jogadas legais, incluindo a regra da
Rainha e o `.pass` quando não há jogada.

- **Implementa:** [[REQ-03 — Colocação de Peças]], [[REQ-04 — Rainha até o 4º turno]], [[REQ-07 — Passe Obrigatório]]
- **Vive em:** [[COD-MoveGenerator]] → `placementCells`, `legalPlacements`, `legalMoves`
- **Testada por:** [[TEST-PlacementTests]]

`legalMoves` = colocações + movimentos de peça; devolve `[.pass]` só quando
ambos são vazios. É a **função geradora** que o [[Perft]] vai enumerar.
