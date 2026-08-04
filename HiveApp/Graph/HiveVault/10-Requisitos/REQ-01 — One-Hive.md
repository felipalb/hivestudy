---
tipo: requisito
id: REQ-01
status: coberto
tags: [hive/requisito]
---

# REQ-01 — One-Hive (colmeia única)

A colmeia deve permanecer **um único grupo conexo** o tempo todo. Nenhuma peça
pode ser movida se, ao ser levantada, dividir a colmeia em duas.

- **Implementado por:** [[MEC-Conectividade]] · [[MEC-Cut Vertex]]
- **Vive em:** [[COD-Board]] (`isConnected`, `isCutVertex`, `connectedComponentCount`)
- **Verificado por:** [[TEST-ConnectivityTests]] · [[TEST-SelfPlayTests]]
- **Teoria de grafo:** [[Componentes Conexos]] · [[Ponto de Articulação]]

## Critérios de aceite

- Uma peça no **meio** de uma linha é ponto de articulação → não move.
- Uma peça na **ponta** não é → move.
- Um besouro **empilhado** nunca é cut vertex (não altera o *footprint*).
- Após qualquer jogada legal, `board.isConnected() == true` (invariante).
