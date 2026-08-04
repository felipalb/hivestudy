---
tipo: mecanica
tags: [hive/mecanica]
---

# MEC-Grasshopper Jump (raio em linha reta)

O Gafanhoto pula em **linha reta** sobre uma fila contígua de peças (≥1) e
pousa na **primeira célula vazia** além. Para cada direção, é um "raio" que
avança enquanto encontra peça.

- **Vive em:** [[COD-Rules]] → `grasshopperDestinations`
- **Testada por:** [[TEST-GrasshopperTests]]
- **Governa:** [[Gafanhoto]]; copiado pelo [[Mosquito]]

Não usa portão nem conectividade de deslize — é o único movimento por "raio".
No app, é o [[Gafanhoto]] que fecha o cerco na última lição do tutorial
(guardado por [[TEST-TutorialScenarioTests]]).
