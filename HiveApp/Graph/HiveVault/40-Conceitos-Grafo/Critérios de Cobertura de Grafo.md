---
tipo: conceito
tags: [hive/conceito]
---

# Critérios de Cobertura de Grafo

Do livro canônico *Ammann & Offutt — Introduction to Software Testing (cap. 7)*.
Dado um grafo do sistema (ex.: máquina de estados), define **o que cobrir**:

| Critério | Exige cobrir | Força |
|----------|--------------|-------|
| Node coverage (NC) | todo nó | fraca |
| Edge coverage (EC) | toda aresta | > NC |
| Edge-pair coverage | todo par de arestas consecutivas | > EC |
| Prime path coverage (PPC) | todos os "prime paths" (inclui ciclos) | forte |

- **No Hive:** modelar o fluxo de turno como grafo e cobrir suas arestas
  → [[Teste Baseado em Modelo (MBT)]].
- É a ponte formal entre **"grafo" e "cobertura de teste"** — cite na entrevista.
