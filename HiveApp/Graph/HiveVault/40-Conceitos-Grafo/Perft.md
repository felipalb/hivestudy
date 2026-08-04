---
tipo: conceito
tags: [hive/conceito, hive/harness]
---

# Perft (performance/enumeration test)

Técnica de engines de xadrez: conta **quantas sequências de jogadas legais**
existem a partir de uma posição até profundidade N, e compara com um valor de
referência. É travessia da [[Árvore de Jogo]] com **contagem de nós**.

## Por que é ouro para QA

- Um único número errado denuncia bug no gerador de movimentos
  ([[MEC-Placement Cells]] / `MoveGenerator`) — sem escrever caso a caso.
- Cobre `legalMoves` inteiro de uma vez; é **teste de regressão** perfeito.

```
perft(estado, 0) = 1
perft(estado, n) = Σ perft(aplicar(m), n-1) para cada m em legalMoves(estado)
```

## No harness

- Golden numbers travados: **perft(1)=5, perft(2)=150, perft(3)=2220** (base game).
- **Divide-perft:** quebrar a contagem por jogada-raiz para localizar a divergência.
- Status: ✅ **coberto** por [[TEST-GraphHarness]] (`PerftTests`). Ver [[Matriz de Rastreabilidade]].
