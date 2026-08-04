---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Cut Vertex (peça que trava)

Uma peça de chão (altura 1) é **ponto de articulação** se removê-la aumenta o
número de componentes conexos. Peça assim **não pode se mover** (violaria
One-Hive). Um besouro empilhado nunca é cut vertex — não muda o footprint.

- **Conceito:** [[Ponto de Articulação]]
- **Implementa:** [[REQ-01 — One-Hive]]
- **Vive em:** [[COD-Board]] → `isCutVertex(_:)`; usado em [[COD-MoveGenerator]]
- **Testada por:** [[TEST-ConnectivityTests]]

```swift
func isCutVertex(_ hex: Hex) -> Bool {
    guard height(hex) == 1 else { return false }
    return connectedComponentCount(excluding: hex) > 1
}
```

> Implementação por *recontagem* (O(V·E) no gerador). Uma otimização clássica é
> o algoritmo de **Tarjan** de pontos de articulação em uma passada — ótima
> oportunidade de **differential testing**: Tarjan vs. recontagem devem dar o
> mesmo conjunto. Ver [[Estratégia de Teste]].
