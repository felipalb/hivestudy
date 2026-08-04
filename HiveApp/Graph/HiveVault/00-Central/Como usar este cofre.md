---
tipo: central
tags: [hive/central]
---

# Como usar este cofre

Volta para [[Início]].

## Convenção de nós

Cada nota é um **nó do grafo**. Notas curtas de propósito — o valor está nos
**links** (arestas) e num resumo enxuto, não em textões.

| Prefixo | Tipo | Exemplo |
|---------|------|---------|
| `REQ-` | Requisito | [[REQ-01 — One-Hive]] |
| `MEC-` | Mecânica | [[MEC-Conectividade]] |
| `TEST-` | Suite de teste | [[TEST-ConnectivityTests]] |
| `COD-` | Arquivo de código | [[COD-Board]] |
| (nome) | Peça / Conceito | [[Formiga]] · [[Ponto de Articulação]] |

## Frontmatter padrão

```yaml
---
tipo: requisito | mecanica | peca | conceito | teste | codigo | central
id: REQ-01              # quando aplicável
status: coberto | parcial | lacuna   # cobertura de teste (só em requisitos)
tags: [hive/requisito]
---
```

## Queries úteis (plugin Dataview, opcional)

Requisitos com lacuna de cobertura:
```dataview
TABLE status FROM "10-Requisitos" WHERE status != "coberto"
```

Notas sem nenhum link de saída (nós órfãos = candidatos a lacuna):
> Use a **Graph View** com "Orphans" ligado, ou o painel *Outgoing/Backlinks*.

## Fluxo de trabalho sugerido

1. Leu uma regra do jogo? → crie/atualize um `REQ-`.
2. Descobriu *como* ela é implementada? → ligue a uma `MEC-` e a um `COD-`.
3. Existe teste que a cobre? → ligue a um `TEST-`. Se **não** existe → marque
   `status: lacuna` e é um teste a escrever (vai pro harness).
4. Reveja a [[Matriz de Rastreabilidade]] — ela é o placar de cobertura.
