---
tipo: requisito
id: REQ-05
status: coberto
tags: [hive/requisito]
---

# REQ-05 — Vitória por Cerco

Vence quem **cercar a Rainha inimiga pelos 6 lados**, não importa de quem sejam
as peças que a cercam.

- **Vive em:** [[COD-GameState]] (`queenSurrounded`, `queenSurroundCount`, `evaluateResult`)
- **Verificado por:** [[TEST-WinTests]]

## Critérios de aceite

- Rainha branca com 6 vizinhos ocupados → `.win(.black)`.
- `queenSurroundCount` conta corretamente 0…6.
- Score da IA é dominado por esse termo (quadrático) — ver [[COD-AI]].
