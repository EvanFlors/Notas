# ADR 002 — Estrategia de reutilización en GitLab CI/CD

> Referencia. **No es la única solución defendible**, pero es la que yo defendería frente a un panel de SRE.

## Estado

Aceptado — 2026-10-16

## Contexto

El grupo `payments/` opera 12 proyectos y 2 workloads en producción. En la última retro de plataforma se identificaron tres situaciones de duplicación de pipelines que están creando bugs sutiles (jobs que divergen entre repos sin que nadie se dé cuenta) y costando ~1 día/semana de mantenimiento repartido.

Las tres situaciones:

- **Escenario A — smoke tests duplicados**. 4 jobs casi idénticos (`smoke:dev`, `smoke:stg`, `smoke:prod`, `smoke:canary`) dentro del mismo `.gitlab-ci.yml` de `payments/checkout-api`. ~60 líneas de duplicación en un solo archivo.
- **Escenario B — pipeline Node compartido entre 3 proyectos**. `checkout-api`, `webhooks-api` y `refunds-worker` comparten lint+test. Mismo grupo, mismo stack, 3 consumidores.
- **Escenario C — build+sign para 11 proyectos cross-grupo**. 4 grupos distintos quieren un mismo flujo `docker build + cosign sign + push`. Compliance exige trazabilidad de versión del flujo usado por deploy.

Esta ADR fija el mecanismo por escenario para los próximos 12 meses.

## Decisión

| Escenario | Mecanismo | Por qué (1 línea) |
|-----------|-----------|-------------------|
| A — smoke tests duplicados | **`extends:` sobre hidden job** | Duplicación local, 1 archivo, 1 lector responsable. |
| B — Node compartido en 3 proyectos | **`include: project:` con `ref:` a tag SemVer** | Pocos consumidores, mismo grupo, cambio tolerable con sync coordinado. |
| C — build+sign cross-grupo | **CI/CD Component con `spec:inputs:` publicado al Catalog** | 11 consumidores cross-grupo + contrato tipado + versionado SemVer requerido por compliance. |

### Escenario A — `extends:`

El `.gitlab-ci.yml` de `checkout-api` extrae un hidden job `.smoke-base` con `image`, `before_script`, `cache` y el `script:` común. Los 4 jobs reales (`smoke:dev`, `smoke:stg`, `smoke:prod`, `smoke:canary`) heredan de `.smoke-base` y solo definen las `variables:` del entorno. Pasa de ~60 líneas a ~25. Sin coste de infraestructura: todo vive en el mismo archivo y mismo commit.

### Escenario B — `include: project:`

Creamos `payments/ci-shared` con `/jobs/node-pipeline.yml`. Los 3 consumidores hacen:

```yaml
include:
  - project: 'payments/ci-shared'
    ref: 'v1.0.0'
    file: '/jobs/node-pipeline.yml'
```

Políticas:
- `ref:` siempre fijo a un tag `vX.Y.Z` (**nunca** `main`).
- Nuevas versiones se anuncian en `#payments-eng` 48h antes del rollout; los consumidores migran en PR.
- Si el crecimiento llega a >5 consumers o cruza a otro grupo, promovemos a componente (ver Escenario C).

### Escenario C — CI/CD Component

Creamos `platform/ci-components` con un componente `build-sign-image`:

```yaml
spec:
  inputs:
    dockerfile:
      default: './Dockerfile'
      description: 'Ruta al Dockerfile.'
    image_name:
      description: 'Nombre completo de la imagen (sin tag).'
    registry:
      default: '$CI_REGISTRY_IMAGE'
      description: 'Registry destino.'
    sign:
      type: boolean
      default: true
      description: 'Si true, firma la imagen con cosign (keyless, ID Token).'
    cosign_identity_regex:
      description: 'Regex del subject esperado en la firma (compliance).'
---
# ... jobs build + sign + push ...
```

Políticas:
- SemVer estricto. `vMAJOR` como alias móvil, `vMAJOR.MINOR.PATCH` como pin inmutable.
- Compliance exige pin a tag inmutable; `~latest` solo se permite para environments no productivos.
- CI/CD Catalog interno del grupo `platform/`.
- Mantenido por el equipo de plataforma, con tests en el propio repo del componente.

## Consecuencias

**Positivas:**

- A: lectura 2x más rápida del pipeline de `checkout-api`.
- B: 1 solo lugar donde arreglar un bug del pipeline Node para 3 repos.
- C: compliance puede probar que el deploy X usó la versión `v1.2.3` del flujo de firma, inmutable y auditable.
- Convergencia operativa: eliminamos ~1 día/semana de drift entre pipelines.

**Negativas:**

- B introduce acoplamiento: cambios en `payments/ci-shared` requieren PRs sincronizados en 3 repos.
- C introduce **blast radius** cross-grupo: una mala publicación de `v2.0.0` rompe el parse en 11 pipelines ajenos. Mitigación: self-test del componente antes de taggear.
- El equipo de plataforma asume ownership del componente — nueva función explícita.
- Costo cognitivo: los nuevos ingenieros deben entender 3 mecanismos y cuándo cada uno (esta misma ADR es parte de la mitigación).

## Alternativas descartadas

1. **Todo con `include: remote:` apuntando a `main` de un repo público** — descartada: sin pin de versión, cualquier push rompe pipelines ajenos; sin `spec:inputs:` el contrato es implícito. Es el anti-patrón canónico.
2. **Un único mecanismo (todo componente, incluso el Escenario A)** — descartada: para 4 jobs duplicados dentro del mismo archivo, un hidden job con `extends:` es 10 líneas y 0 overhead; un componente son 3 archivos, un repo, un tag, una CI de self-test. Overkill masivo.
3. **Composite action adaptada desde GHA via wrapper** — descartada: GitLab tiene mecanismos nativos (componentes) con mejor fidelidad (`spec:inputs:` tipado, `options:`, `regex:`); traducir composite a hidden job no agrega valor.
4. **Mantener la duplicación y automatizar sync con un bot** — descartada: la duplicación "con bot" sigue siendo duplicación, y el bot es ahora un sistema más que mantener.

## Anti-patrones evitados

- **`include: remote:` con `main`**: fragilidad; migración forzada a componente o `include: project:` con tag.
- **`extends:` de más de 2 niveles**: lectura imposible; cuando pasa, aplanamos o convertimos a componente.
- **Componente sin `spec:inputs:`**: no es un contrato, es un `include: project:` disfrazado; degradamos o añadimos inputs reales.
- **Consumer apuntando a `main` del componente**: pin obligatorio a tag; CI del propio componente debe testarse en una rama antes del tag.

## Revisión

Esta ADR se revisa a los 6 meses (abril 2027) o cuando:

- El Escenario B pase de 3 a >5 consumidores → candidato a componente.
- Aparezca un 4º escenario que no encaje → ampliar la tabla.
- GitLab anuncie breaking changes en el formato de componentes.
