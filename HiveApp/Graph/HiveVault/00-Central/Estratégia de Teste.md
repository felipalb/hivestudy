---
tipo: central
tags: [hive/central]
---

# 🎯 Estratégia de Teste

Volta para [[Início]].

Técnicas de **graph engineering** aplicadas ao `HiveEngine`, da teoria aos
testes automatizados.

## As 6 frentes

1. **Teste unitário dos algoritmos de grafo** — tratar `Board`/`Rules` como uma
   biblioteca de grafos. Ver [[Componentes Conexos]], [[Ponto de Articulação]],
   [[Busca em Largura (BFS)]], [[Busca em Profundidade (DFS)]].
2. **[[Teste por Propriedades]] e [[Teste Metamórfico]]** — invariantes que
   valem em *qualquer* partida (conectividade nunca quebra, mover/desmover é
   idempotente, simetria rotacional).
3. **[[Perft]]** — enumeração da [[Árvore de Jogo]] com contagem de nós; um
   número errado denuncia bug no gerador de movimentos.
4. **[[Teste Baseado em Modelo (MBT)]]** com [[Critérios de Cobertura de Grafo]]
   — modelar o fluxo de turno como máquina de estados e cobrir arestas/caminhos.
5. **Differential testing** — implementação ingênua vs. otimizada devem
   concordar (ex.: BFS da Formiga vs. flood-fill trivial).
6. **Rastreabilidade como grafo** — este cofre. Cobertura visível na
   [[Matriz de Rastreabilidade]].

## Trilha de estudo (3 sprints)

- **Sprint 1 — fundação:** este cofre (grafo de rastreabilidade) + ler os
  algoritmos em [[COD-Board]], [[COD-Rules]], [[COD-MoveGenerator]].
- **Sprint 2 — impacto rápido:** harness de [[Perft]] + [[Teste por Propriedades]]
  (pouco código, cobertura enorme).
- **Sprint 3 — diferencial teórico:** [[Teste Baseado em Modelo (MBT)]] com
  [[Critérios de Cobertura de Grafo]] (citar Ammann & Offutt).

## Vocabulário para a entrevista

`graph coverage criteria` · `model-based testing` · `metamorphic testing` ·
`property-based testing` · `perft` · `articulation points / cut vertices` ·
`connected components` · `differential testing` · `traceability matrix`

## Estado atual da suíte (`HiveEngineTests.swift`)

37 testes em 13 suites — ver pasta `50-Testes`. Já cobre: geometria, One-Hive,
deslize, Aranha/Formiga, Besouro, Gafanhoto, Joaninha, Mosquito, colocação,
pinning, vitória, self-play (invariante de conectividade) e IA.
**Lacunas conhecidas** viram trabalho no harness — ver [[Matriz de Rastreabilidade]].
