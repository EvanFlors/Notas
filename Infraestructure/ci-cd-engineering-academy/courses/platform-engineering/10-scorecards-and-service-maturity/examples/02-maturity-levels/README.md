# Ejemplo 02 — De 5–8 chequeos a bronze / silver / gold

> Lectura y análisis. Objetivo: entender cómo repartir los 5–8 chequeos canónicos entre niveles sin crear un peso ponderado opaco.

## 1. Punto de partida

Los 8 chequeos canónicos propuestos en `theory/lesson.md` §3 son:

1. tiene owner
2. tiene SLO
3. tiene runbook
4. tiene on-call rotation
5. imagen firmada
6. sin CVEs críticos
7. deployed en los últimos 90 días
8. namespace con PSA restricted

Ahora toca repartirlos.

## 2. El reparto propuesto

| Nivel | Chequeos requeridos | Qué está diciendo el nivel |
|---|---|---|
| **bronze** | 1 (owner) | *"Existe en condiciones mínimas de operabilidad."* Sabemos a quién llamar. |
| **silver** | 1 + 2, 3, 4 (owner + SLO + runbook + on-call) | *"Puede operar en producción con un on-call razonable."* Hay contrato operativo, procedimiento y rotación. |
| **gold** | 1 + 2 + 3 + 4 + 5, 6, 7, 8 (todo lo anterior + supply chain + postura k8s + evidencia de vida) | *"Mejora la postura global de la plataforma."* |

La regla clave: para estar en nivel N hay que **pasar todos los chequeos de los niveles ≤ N**. No se "pondera", no se "redondea", no hay "silver con asterisco". Esta rigidez es lo que mantiene al scorecard legible.

## 3. Cómo se ve esto en `scorecard.yaml`

```yaml
levels:
  - bronze
  - silver
  - gold

checks:
  - id: has-owner
    weight: bronze
    field: owner
    operator: is_set

  - id: has-slo
    weight: silver
    field: annotations.slo_url
    operator: is_set

  - id: has-runbook
    weight: silver
    field: annotations.runbook_url
    operator: is_set

  - id: has-oncall
    weight: silver
    field: annotations.oncall_rotation
    operator: is_set

  - id: image-signed
    weight: gold
    field: annotations.image_signed
    operator: equals
    value: true

  - id: no-critical-cves
    weight: gold
    field: annotations.cves_critical
    operator: equals
    value: 0

  - id: deployed-recently
    weight: gold
    field: annotations.last_deploy_days
    operator: less_than
    value: 90

  - id: psa-restricted
    weight: gold
    field: annotations.k8s_psa
    operator: equals
    value: restricted
```

## 4. Qué pasa con un servicio real

Imagina `checkout-api` con estas anotaciones:

```json
{
  "owner": "team-payments",
  "annotations": {
    "slo_url": "https://wiki/slo/checkout",
    "runbook_url": "https://wiki/runbook/checkout",
    "oncall_rotation": "checkout-primary",
    "image_signed": true,
    "cves_critical": 2,
    "last_deploy_days": 7,
    "k8s_psa": "baseline"
  }
}
```

Resultado:

- bronze: **pasa** (tiene owner).
- silver: **pasa** (tiene SLO, runbook, on-call).
- gold: **no pasa** → le fallan `no-critical-cves` (2 ≠ 0) y `psa-restricted` (baseline ≠ restricted).

**Nivel final: silver. Gap a gold: 2 chequeos.**

Esto es exactamente el mensaje que recibe el equipo. No es un número; es una lista corta y accionable.

## 5. Por qué no usamos pesos continuos

El antipatrón canónico es:

```yaml
# NO HACER ESTO
score = 0.3 * check_a + 0.1 * check_b + 0.2 * check_c + 0.15 * ... = 73.4
```

Problemas:

- Nadie entiende por qué subió o bajó el número.
- Dos equipos con **gaps diferentes** (uno sin SLO, otro sin PSA restricted) pueden tener el **mismo score**. Eso borra información.
- Los pesos invitan a litigio: *"¿por qué owner vale 0.3 y PSA 0.15?"*.

El modelo escalonado (bronze/silver/gold por conjunto) es menos "sofisticado" y mucho más defendible.

## 6. Cuándo sí tiene sentido ponderar

Cuando el chequeo **no es booleano** sino **escalar y continuo**. Ejemplo: *coverage de tests* (0–100 %). Pero incluso ahí, la receta sana es **binarizarlo con un umbral** (`coverage >= 70 ⇒ pasa`) y meterlo al nivel que corresponda. Nunca el score mezcla booleanos con escalares; es un dolor de cabeza.

## 7. Qué hacer con esto

1. Memoriza el reparto 1 / 4 / 4 (bronze/silver/gold) como punto de partida razonable.
2. En la actividad `01-scorecard-for-capstone/` vas a **adaptarlo a tu capstone**. Puedes mover un chequeo de gold a silver si lo defiendes.
3. Lee `examples/03-adoption-dashboard/` para ver cómo se publica la adopción agregada que sale de este reparto.
