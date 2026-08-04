---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Conectividade (componentes conexos)

O *footprint* (células ocupadas, ignorando empilhamento) precisa formar **um só
componente conexo**. Implementado com uma travessia (DFS iterativa) que conta
componentes e faz *early-exit* ao achar o segundo.

- **Conceito:** [[Componentes Conexos]]
- **Implementa:** [[REQ-01 — One-Hive]]
- **Vive em:** [[COD-Board]] → `connectedComponentCount(excluding:)`, `isConnected()`
- **Testada por:** [[TEST-ConnectivityTests]], [[TEST-SelfPlayTests]]

```swift
func connectedComponentCount(excluding excluded: Hex?) -> Int
```

O parâmetro `excluding` é a chave: simular "e se esta célula sumisse?" é o que
transforma essa contagem em detecção de [[Ponto de Articulação]] → ver
[[MEC-Cut Vertex]].
