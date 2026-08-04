---
tipo: teste
suite: SlideTests
tags: [hive/teste]
---

# TEST-SlideTests

- `wedgedBetweenTwoTilesCannotSlide` — dois portões ocupados → encravada.
- `oneOpenGateCanSlide` — um portão ocupado → desliza.
- `detachedSlideIsIllegal` — nenhum portão → destacaria.
- `occupiedDestinationBlocksSlide` — destino ocupado → bloqueado.

**Cobre:** [[REQ-02 — Liberdade de Movimento]] · **Mecânica:** [[MEC-Ground Slide]]
· **Código:** [[COD-Rules]] · **Peça:** [[Rainha]] (parcial)
