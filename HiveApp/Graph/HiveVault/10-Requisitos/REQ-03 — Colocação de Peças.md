---
tipo: requisito
id: REQ-03
status: coberto
tags: [hive/requisito]
---

# REQ-03 — Colocação de Peças

Ao **colocar** uma peça nova, ela deve tocar uma peça amiga e **nenhuma** peça
inimiga — com as exceções da abertura (primeira peça no `origin`; a primeira
peça do 2º jogador pode encostar no oponente).

- **Implementado por:** [[MEC-Placement Cells]]
- **Vive em:** [[COD-MoveGenerator]] (`placementCells`, `legalPlacements`)
- **Verificado por:** [[TEST-PlacementTests]]

## Critérios de aceite

- 1ª jogada → só `origin`; 5 bugs-base colocáveis.
- 2º jogador → qualquer um dos 6 lados do oponente.
- Após a abertura → célula que toca amigo e não toca inimigo.
