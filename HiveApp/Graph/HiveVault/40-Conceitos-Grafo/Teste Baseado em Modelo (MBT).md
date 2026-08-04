---
tipo: conceito
tags: [hive/conceito, hive/harness]
---

# Teste Baseado em Modelo (MBT)

Modela-se o sistema como um **grafo/máquina de estados** e **geram-se** casos de
teste percorrendo caminhos que satisfazem um [[Critérios de Cobertura de Grafo|critério de cobertura]].

## Modelo do fluxo de turno do Hive

```
[Início] --place 1ª--> [Abertura]
[Abertura] --place/queen--> [Colocação]
[Colocação] --4º turno sem Rainha--> [DeveColocarRainha] --place Rainha--> [Movimento]
[Movimento] <--move/place/pass--> [Movimento]
[Movimento] --cerca Rainha--> [Vitória/Empate]  (terminal)
```

- Gerar sequências que cobrem **todas as arestas** (edge coverage) e rodar
  contra o `HiveEngine`, checando invariantes a cada passo.
- **No Hive:** transições = `legalMoves`; oráculo = invariantes ([[Teste por Propriedades]]).
- Status: **lacuna** → sprint 3 do harness. Ver [[Estratégia de Teste]].
