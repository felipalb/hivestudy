---
tipo: conceito
tags: [hive/conceito, hive/harness]
---

# Teste Metamórfico

Quando não há oráculo exato ("qual a resposta certa?"), testa-se uma **relação
metamórfica**: uma transformação da entrada cujo efeito na saída é conhecido.

## Relações no Hive

- **Simetria rotacional:** rotacionar o tabuleiro 60° deve **rotacionar** o
  conjunto de movimentos legais (mesma cardinalidade, imagens correspondentes).
- **Reflexão:** espelhar o tabuleiro espelha os destinos.
- **Passo unitário:** `exactSlideDestinations(steps: 1) == groundSlideSteps`.
- **Subconjunto:** destinos da [[Aranha]] ⊆ [[Formiga]].
- **Round-trip:** aplicar e reverter uma jogada volta ao estado idêntico.

Ótimo para pegar bugs de **geometria hexagonal** que casos pontuais não pegam.
Status: ✅ **coberto** — rotação 60° e round-trip em [[TEST-GraphHarness]]
(`MetamorphicTests`). Reflexão ainda em aberto. Ver [[Teste por Propriedades]].
