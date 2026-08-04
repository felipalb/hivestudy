---
tipo: central
tags: [hive/central]
---

# 🐝 HiveVault — Grafo de Rastreabilidade de QA

Cofre de estudo e **engenharia de grafos aplicada a testes** do projeto Hive
(implementação SwiftUI do jogo de tabuleiro Hive).

> [!tip] Abra a **Graph View** (`Ctrl/Cmd+G`)
> Cada cor é um tipo de nó. Um **requisito sem aresta para nenhum teste** =
> lacuna de cobertura, visível de imediato. É essa a ideia central: usar o
> grafo do Obsidian como **matriz de rastreabilidade viva**.

## Como o grafo está montado

| Cor | Tipo de nó | Pasta | Papel |
|-----|-----------|-------|-------|
| 🟢 Verde-água | [[Como usar este cofre]] · central | `00-Central` | índices e estratégia |
| 🔴 Vermelho | Requisito | `10-Requisitos` | *o que* o jogo garante |
| 🔵 Azul | Mecânica | `20-Mecanicas` | *como* uma regra é implementada (o algoritmo de grafo) |
| 🟢 Verde | Peça | `30-Pecas` | os 8 bugs, ligando peça → mecânica → teste |
| 🟣 Roxo | Conceito de grafo | `40-Conceitos-Grafo` | a teoria (BFS, cut vertex, Perft, MBT…) |
| 🟡 Amarelo | Teste | `50-Testes` | suites reais em `HiveEngineTests.swift` |
| ⚪ Cinza | Código | `60-Codigo` | arquivos do `HiveEngine` |

## Sentido das arestas (traceability)

```
Requisito  --verificado por-->  Teste
Requisito  --implementado em-->  Mecânica / Código
Mecânica   --usa-->  Conceito de grafo
Mecânica   --vive em-->  Código
Peça       --governada por-->  Mecânica
Teste      --cobre-->  Peça / Mecânica / Requisito
```

## Portas de entrada

- 🗺️ [[Matriz de Rastreabilidade]] — a tabela REQ → MEC → COD → TEST
- 🎯 [[Estratégia de Teste]] — as técnicas de grafo e a trilha de estudo
- 📖 [[Como usar este cofre]] — convenções, tags e queries úteis

## Insight de uma frase

> Hive **é** um grafo (tabuleiro = grafo, regra One-Hive = conectividade,
> movimento = travessia, IA = árvore de jogo). Então testar Hive é
> **engenharia de grafos dos dois lados**: os algoritmos testados são de grafo,
> e a estratégia de teste é modelada como grafo.
