---
tipo: requisito
id: REQ-06
status: coberto
tags: [hive/requisito]
---

# REQ-06 — Empate

Se **ambas** as Rainhas ficarem cercadas ao mesmo tempo (tipicamente pela mesma
jogada), o jogo é **empate**.

- **Vive em:** [[COD-GameState]] (`evaluateResult`, caso `(true, true)`)
- **Verificado por:** [[TEST-WinTests]]

## Critérios de aceite

- Duas Rainhas cercadas → `.draw`.
- Uma só cercada → `.win` do oponente correspondente, nunca empate.
