---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Beetle Gate (portão por altura)

O Besouro pode subir na colmeia. O portão vira **3D**: bloqueado só quando os
dois portões são mais altos que o chão de saída **e** o de chegada. Sobe em
pilha (mantém contato) ou desce em célula que toca a colmeia.

- **Vive em:** [[COD-Rules]] → `canBeetleMove`, `beetleDestinations`
- **Testada por:** [[TEST-BeetleTests]], [[TEST-PinningTests]]
- **Governa:** [[Besouro]]; copiado pelo [[Mosquito]] quando em cima da colmeia

Empilhar um Besouro sobre outra peça a **imobiliza** (pinning) — testado em
[[TEST-PinningTests]]. Também é o único jeito do [[Mosquito]] subir; uma vez em
cima, o mosquito só se move como besouro ([[MEC-Mosquito Copy]]).
