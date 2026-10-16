# Ejemplo 01 — TechInsights: anatomía de *fact* + *check* + *score*

> Lectura y análisis. No se levanta Backstage. El objetivo es fijar el modelo mental antes de las actividades.

## 1. Qué miramos

Un **fact collector** lee un hecho de un sistema externo. Un **check** aplica una regla a uno o más facts. Un **score** agrega checks. Lo mismo que ofrece TechInsights lo vamos a representar con YAML y JSON locales, porque conceptualmente es idéntico.

## 2. Un fact típico (shape)

En TechInsights real, un fact collector persiste algo así (serializado — mostrado como JSON para legibilidad):

```json
{
  "entityRef": "component:default/checkout-api",
  "collector": "pagerduty-oncall-fact",
  "ts": "2026-10-10T12:00:00Z",
  "facts": {
    "hasOnCallRotation": true,
    "rotationName": "checkout-primary"
  }
}
```

Las claves relevantes:

- **`entityRef`** — el sujeto evaluado. Siempre viene del catálogo.
- **`collector`** — quién produjo el fact. Útil para auditar.
- **`ts`** — cuándo se tomó. Un fact "demasiado viejo" se trata como ausente.
- **`facts`** — los datos. **Nunca** opiniones.

En este módulo representamos los facts como campos dentro de la ficha de servicio en `activities/01-scorecard-for-capstone/starter/catalog/*.json`. Cada servicio tiene algo como:

```json
{
  "ref": "component:default/checkout-api",
  "owner": "team-payments",
  "annotations": {
    "slo_url": "https://wiki/slo/checkout",
    "runbook_url": "https://wiki/runbook/checkout",
    "oncall_rotation": "checkout-primary",
    "image_signed": true,
    "cves_critical": 0,
    "last_deploy_days": 7,
    "k8s_psa": "restricted"
  }
}
```

Las anotaciones **son** los facts. En Backstage reales, provienen de collectors; aquí los pre-rellenamos para que puedas iterar sobre la lógica de los checks sin montar la infra.

## 3. Un check típico (shape)

Un check en TechInsights se escribe en forma de regla sobre uno o más facts. Representado en YAML, el patrón recomendado para este módulo es:

```yaml
checks:
  - id: has-slo
    description: El servicio tiene SLO publicado y enlazado.
    weight: silver
    field: annotations.slo_url
    operator: is_set

  - id: no-critical-cves
    description: Sin CVEs críticos en la imagen.
    weight: gold
    field: annotations.cves_critical
    operator: equals
    value: 0

  - id: deployed-recently
    description: Deploy exitoso en los últimos 90 días.
    weight: gold
    field: annotations.last_deploy_days
    operator: less_than
    value: 90
```

Lo que estás viendo:

- Cada check tiene **un `id`** (estable), **una descripción** (humana), **un peso** expresado como el **nivel** al que pertenece, y una **regla** (`field` + `operator` [+ `value`]).
- Los operadores son deliberadamente pocos: `is_set`, `equals`, `less_than`, `greater_than`, `in`. Si necesitas más, probablemente estás metiendo complejidad en el chequeo que debería estar en el collector.

## 4. Score y niveles

A diferencia de un score ponderado continuo (0–100), aquí usamos una **regla simple y defendible**:

- Un servicio está en **bronze** si pasa todos los checks `weight: bronze`.
- Está en **silver** si pasa todos los de bronze + todos los de silver.
- Está en **gold** si pasa todos los de bronze + silver + gold.
- Si no pasa todos los de bronze, está **unranked** (no "pre-bronze"; literalmente **no cumple el mínimo**).

Ventaja: cualquiera entiende por qué un servicio **no** está en gold. *"Le falta el check `no-critical-cves`."* Fin de la conversación.

Desventaja aparente: no hay "casi gold". **Esto es intencional.** Un servicio con un CVE crítico no es "casi gold"; **no es gold**. La laxitud ponderada es precisamente lo que gamifica el sistema.

## 5. Qué veríamos en Backstage real (vista previa)

En Backstage con TechInsights habilitado, la página de la entidad `component:default/checkout-api` tendría un panel *"Scorecard"* con una lista de chequeos (verde/rojo) y la etiqueta de nivel. La página también mostraría el gap para subir ("faltan 2 chequeos para gold") y los enlaces a la **documentación por chequeo** (ver `theory/lesson.md` §6).

No hace falta levantar Backstage para construir ese modelo mental. En las actividades reproduces exactamente el mismo flujo con un script Python local.

## 6. Correspondencia con TechInsights real

| En este módulo | En TechInsights real |
|---|---|
| JSON por servicio en `catalog/` | Entidad en el catálogo + facts persistidos por collectors |
| `scorecard.yaml` con `checks[]` | Checks escritos en JSON Rules Engine registrados vía `TechInsightsBackend` |
| `evaluate.py` que recorre y aplica | Backend de TechInsights ejecutando los checks |
| Reporte Markdown | Panel UI en la página de la entidad |

Lo que cambia es **dónde corre** y **quién lo pinta**. La semántica es la misma.

## 7. Qué hacer con esto

1. Lee las dos listas (facts y checks) hasta que las dos columnas (dato vs regla) se te queden fijas.
2. Pasa a `examples/02-maturity-levels/` para ver cómo mapear 5–8 checks a bronze/silver/gold.
3. En la actividad `01-scorecard-for-capstone/` **escribes tu propio** `scorecard.yaml` y lo evalúas con `scripts/evaluate.py`.
