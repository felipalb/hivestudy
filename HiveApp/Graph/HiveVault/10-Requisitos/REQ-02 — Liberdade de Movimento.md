---
tipo: requisito
id: REQ-02
status: coberto
tags: [hive/requisito]
---

# REQ-02 — Liberdade de Movimento (freedom to move)

Uma peça que desliza pelo chão só passa por uma aresta se puder **fisicamente
deslizar**: das duas células "portão" que ladeiam a aresta, **exatamente uma**
deve estar ocupada (uma dá a parede pra encostar, a outra dá a brecha).

- Ambas ocupadas → encravada. Ambas vazias → destacaria da colmeia.
- **Implementado por:** [[MEC-Ground Slide]]
- **Vive em:** [[COD-Rules]] (`canGroundSlide`) · [[COD-Hex]] (`gates`)
- **Verificado por:** [[TEST-SlideTests]]
- **Governa:** [[Rainha]], [[Formiga]], [[Aranha]], [[Besouro]] no chão

## Critérios de aceite

- Encravada entre dois vizinhos → não desliza.
- Um só portão ocupado → desliza.
- Nenhum portão ocupado → ilegal (destacaria).
- Destino ocupado → bloqueado.
