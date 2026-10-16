# REFERENCE — plat-10-01-scorecard-for-capstone

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `scorecard.yaml` (modelo)

Usa los **8 canónicos** repartidos 1 / 3 / 4 (bronze/silver/gold). Es el reparto más defendible para un capstone típico porque:

- bronze es el mínimo absoluto de operabilidad: *tienes a quién llamar*.
- silver es "puedes dormir": SLO + runbook + on-call.
- gold incorpora supply chain + evidencia de vida + postura k8s.

```yaml
name: capstone-maturity
levels: [bronze, silver, gold]

checks:
  - { id: has-owner,         weight: bronze, field: owner,                       operator: is_set,     description: "Owner definido." }
  - { id: has-slo,           weight: silver, field: annotations.slo_url,         operator: is_set,     description: "SLO publicado." }
  - { id: has-runbook,       weight: silver, field: annotations.runbook_url,     operator: is_set,     description: "Runbook enlazado." }
  - { id: has-oncall,        weight: silver, field: annotations.oncall_rotation, operator: is_set,     description: "Rotación on-call activa." }
  - { id: image-signed,      weight: gold,   field: annotations.image_signed,    operator: equals, value: true,       description: "Imagen firmada." }
  - { id: no-critical-cves,  weight: gold,   field: annotations.cves_critical,   operator: equals, value: 0,          description: "Sin CVEs críticos." }
  - { id: deployed-recently, weight: gold,   field: annotations.last_deploy_days,operator: less_than, value: 90,      description: "Deploy en los últimos 90 días." }
  - { id: psa-restricted,    weight: gold,   field: annotations.k8s_psa,         operator: equals, value: restricted, description: "PSA restricted." }
```

Chequeos **descartados** y por qué:

- `coverage > 80 %`: se infla con tests triviales (gaming).
- `commits/semana > N`: mide actividad, no resultado.
- `n_docs > N`: se infla con placeholders.
- `tiene archivo CODEOWNERS`: redundante con `has-owner` (y mide forma, no contenido).

## `NOTES.md` (modelo)

### Sección A — Decisiones de diseño

- 8 chequeos (el máximo recomendado) porque mi capstone cubre un dominio de pagos y la postura de supply chain + k8s es no-negociable. Si fuera un capstone pedagógico más chico, bajaría a 5–6 (quitaría `psa-restricted` y `image-signed`).
- Descartados: `coverage > 80 %` y `commits/semana` por *gaming*; `n_docs` por lo mismo.
- Reparto 1/3/4: bronze = owner (mínimo); silver = los 3 operativos (SLO, runbook, on-call); gold = los 4 de postura (image-signed, cves, deploy reciente, PSA).

### Sección B — Lectura del reporte

Resultado con los 5 servicios sintéticos del starter:

- `checkout-api`: **gold** (pasa todo).
- `fraud-detector`: **silver** (le fallan `no-critical-cves` y `psa-restricted`).
- `notifier`: **bronze** (le falta `has-runbook`, lo que ya lo saca de silver).
- `legacy-reporting`: **bronze** (solo tiene owner; falla todo lo demás).
- `orphan-cronjob`: **unranked** (no tiene owner; literalmente ni bronze).

Adopción: 80 % ≥ bronze, 40 % ≥ silver, 20 % ≥ gold.

- **Más cerca de subir**: `fraud-detector` (2 chequeos para gold).
- **Más inversión**: `legacy-reporting` (le faltan los 3 de silver y los 4 de gold).

### Sección C — Adopción y antipatrones

Dos cortes que publicaría:

1. **Por tier** (tier-1 / tier-2 / tier-3): porque la inversión se prioriza por tier.
2. **Por antigüedad del servicio**: para ver si las plantillas nuevas producen servicios que ya nacen en silver.

Dos cortes que **no** publicaría:

1. **Ranking entre equipos**: destruye cooperación y gamifica.
2. **"Top 10 peores servicios"**: convierte el scorecard en *stick* y aleja a esos equipos de la plataforma.

Antipatrones evitados:

- **Peso ponderado opaco**: uso niveles con conjuntos fijos de chequeos. Un servicio en gold cumple todos los de gold, no "la mayoría".
- **40 chequeos**: me quedo en 8 y me permito añadir uno nuevo solo si mato otro.
- **Chequeo sin página de ayuda**: cada chequeo tiene su `description` (y en Backstage real, su página de documentación con el escalation path).

## Resultado esperado del evaluador

Al correr `python3 scripts/evaluate.py --scorecard scorecard.yaml --catalog catalog/ --out .` con el scorecard modelo arriba, los números deben ser idénticos a los de la sección B. Si no lo son, revisa que no hayas cambiado silenciosamente `operator` o `value` en alguno de los chequeos.

## Punto a repetir hasta que suene aburrido

> **Scorecard = fact + check + score, bronze/silver/gold como conjuntos (no pesos), adopción agregada como KPI (no ranking), 5–8 chequeos (no 50).**
