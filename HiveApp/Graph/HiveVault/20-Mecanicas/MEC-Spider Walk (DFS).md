---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Spider Walk (DFS de profundidade exata)

A Aranha anda **exatamente 3 passos** deslizando, sem revisitar célula no
caminho. É uma **busca em profundidade** com caminho visitado e profundidade
fixa.

- **Conceito:** [[Busca em Profundidade (DFS)]] · [[Caminho de Comprimento Fixo]]
- **Vive em:** [[COD-Rules]] → `exactSlideDestinations(on:from:steps:)`
- **Testada por:** [[TEST-SpiderAntTests]]
- **Governa:** [[Aranha]]

```swift
static func exactSlideDestinations(on:from:steps:) -> Set<Hex>
```

`steps: 1` deve coincidir com `groundSlideSteps` (ver `oneStepMatchesGroundSlideSteps`)
— outra relação metamórfica boa de fixar.
