---
tipo: requisito
id: REQ-07
status: parcial
tags: [hive/requisito]
---

# REQ-07 — Passe Obrigatório

Se um jogador **não tem nenhuma jogada legal** (nem colocação nem movimento),
ele é obrigado a **passar** (`.pass`) — e o jogo não pode travar.

- **Implementado por:** [[MEC-Placement Cells]] (via `legalMoves` devolver `[.pass]`)
- **Vive em:** [[COD-MoveGenerator]] (`legalMoves`)
- **Verificado por:** [[TEST-SelfPlayTests]] (só de raspão — sempre há ≥ `.pass`)

## Critérios de aceite / lacuna

- `legalMoves` nunca devolve vazio numa partida em andamento. ✅ (self-play)
- ⚠️ **Lacuna:** falta um caso **construído** onde o único movimento legal é
  `.pass`. Candidato ao harness → ver [[Matriz de Rastreabilidade]].
