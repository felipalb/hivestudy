---
tipo: central
tags: [hive/central]
---

# 🗺️ Matriz de Rastreabilidade

Volta para [[Início]]. O placar de cobertura: cada requisito ligado à mecânica
que o implementa, ao código e ao(s) teste(s) que o verificam.

> [!info] Como ler
> `coberto` = há teste direto · `parcial` = coberto só de raspão (ex.: via
> self-play) · `lacuna` = **sem teste** → candidato ao harness.

| Requisito | Mecânica | Código | Teste(s) | Status |
|-----------|----------|--------|----------|--------|
| [[REQ-01 — One-Hive]] | [[MEC-Conectividade]], [[MEC-Cut Vertex]] | [[COD-Board]] | [[TEST-ConnectivityTests]], [[TEST-SelfPlayTests]] | coberto |
| [[REQ-02 — Liberdade de Movimento]] | [[MEC-Ground Slide]] | [[COD-Rules]] | [[TEST-SlideTests]] | coberto |
| [[REQ-03 — Colocação de Peças]] | [[MEC-Placement Cells]] | [[COD-MoveGenerator]] | [[TEST-PlacementTests]] | coberto |
| [[REQ-04 — Rainha até o 4º turno]] | [[MEC-Placement Cells]] | [[COD-GameState]] | [[TEST-PlacementTests]] | coberto |
| [[REQ-05 — Vitória por Cerco]] | — | [[COD-GameState]] | [[TEST-WinTests]] | coberto |
| [[REQ-06 — Empate]] | — | [[COD-GameState]] | [[TEST-WinTests]] | coberto |
| [[REQ-07 — Passe Obrigatório]] | [[MEC-Placement Cells]] | [[COD-MoveGenerator]] | [[TEST-SelfPlayTests]] | parcial |

## Cobertura por mecânica de movimento

| Peça | Mecânica | Teste | Status |
|------|----------|-------|--------|
| [[Rainha]] | [[MEC-Ground Slide]] | [[TEST-SlideTests]] | parcial |
| [[Formiga]] | [[MEC-Ant Reachable (BFS)]] | [[TEST-SpiderAntTests]] | coberto |
| [[Aranha]] | [[MEC-Spider Walk (DFS)]] | [[TEST-SpiderAntTests]] | coberto |
| [[Besouro]] | [[MEC-Beetle Gate]] | [[TEST-BeetleTests]], [[TEST-PinningTests]] | coberto |
| [[Gafanhoto]] | [[MEC-Grasshopper Jump]] | [[TEST-GrasshopperTests]] | coberto |
| [[Joaninha]] | [[MEC-Ladybug]] | [[TEST-LadybugTests]] | coberto |
| [[Mosquito]] | [[MEC-Mosquito Copy]] | [[TEST-MosquitoTests]] | coberto |
| [[Pillbug]] | — (sem movimento) | — | **lacuna** |

## Lacunas → fechadas pelo [[TEST-GraphHarness]]

- [x] **[[Perft]]** — enumeração da árvore de jogo com golden numbers 5/150/2220
  + divide-perft estrutural. → `PerftTests`.
- [x] **[[Teste Metamórfico]] de simetria** — rotação 60° comuta com BFS/deslize.
  → `MetamorphicTests`.
- [x] **Round-trip levantar/repor** ([[Teste por Propriedades]]) — `liftAndReplaceIsIdentity`.
- [x] **[[MEC-Cut Vertex]] ⇒ 0 destinos** — invariante agora testada em toda partida.
- [x] **[[REQ-07 — Passe Obrigatório]]** — contrato "`.pass` é exclusivo" agora
  property-tested (`invariantsHoldThroughoutRandomGames`).

## Lacunas ainda abertas

- [ ] **Reflexão** (além da rotação) como 2ª relação metamórfica.
- [ ] **[[Rainha]] isolada** — falta teste de destinos da Rainha direto do `MoveGenerator`.
- [ ] **[[Teste Baseado em Modelo (MBT)]]** — modelar o fluxo de turno e cobrir
  arestas ([[Critérios de Cobertura de Grafo]]). Sprint 3.
- [ ] **Caso construído** "único movimento legal é `.pass`" (hoje só via contrato).
- [ ] **[[Pillbug]]** — coloca mas não move; *known gap* do produto (teste-guarda opcional).
