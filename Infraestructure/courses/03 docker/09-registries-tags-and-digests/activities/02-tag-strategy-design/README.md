# Actividad 02 — Diseño de estrategia de tagging (ADR)

## 1. Identificación

- **ID:** `dkr-09-02-tag-strategy-design`
- **Tecnología:** `docker`
- **Módulo:** `dkr-09-registries-tags-and-digests`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Las decisiones de tagging no tienen "una respuesta correcta". Dependen del tipo de artefacto, del público consumidor, del registry disponible, del ciclo de release y de qué nivel de reproducibilidad se exige. Esta actividad te pide **tomar y defender esas decisiones** por escrito, en formato ADR (Architecture Decision Record), para un escenario concreto.

El validador **no evalúa la decisión** (no hay una óptima universal). Evalúa que el documento tenga la **estructura mínima de un ADR útil**: contexto, decisiones explícitas (una por eje) y rationale.

## 3. Objetivos

Al terminar:

- Produces `tag-strategy.md` con la estructura obligatoria.
- Decides explícitamente, para el escenario dado:
  - Qué tags inmutables publicas.
  - Qué tags mutables publicas.
  - Qué pin usa producción.
  - Qué pin usa staging / dev.
  - Cómo se rotan las imágenes base (`FROM ...`).
  - Qué pasa con `latest`.
- Justificas cada decisión con una razón explícita (no "porque sí").

## 4. Escenario

Equipo `platform/orders-api`:

- Servicio HTTP interno en Python/FastAPI, versionado **semver**.
- Repo en GitHub, pipeline en GitHub Actions.
- Cluster destino: Kubernetes gestionado (GKE Autopilot).
- Registry autoritativo: **GHCR** (`ghcr.io/acme/orders-api`).
- Deploy manejado por **Argo CD** (GitOps): el `deployment.yaml` vive en un repo `infra/` y se actualiza con PRs.
- Base image: `python:3.12-slim` (hoy sin pin a digest).
- Hay **tres entornos**: `dev` (branch main), `staging` (previo a release), `prod` (release tagueado).
- Preview environments por PR son requisito del equipo frontend que depende de este servicio.
- Compliance (SOC 2) exige que cualquier bit que corra en producción sea **trazable** a un commit específico y auditable después del hecho.

## 5. Prerrequisitos

- `theory/lesson.md` leído completo, especialmente secciones 2, 7 y 8.
- Haber hecho la actividad 01 (`publish-and-consume-your-image`).

**Costos potenciales**: $0 (es solo escritura).

## 6. Instrucciones

### 6.1 Preparar

```bash
bash courses/docker/09-registries-tags-and-digests/activities/02-tag-strategy-design/starter/bootstrap.sh /tmp/dkr-09-strategy
```

El bootstrap crea `/tmp/dkr-09-strategy/tag-strategy.md` con un **esqueleto obligatorio** (secciones vacías) y un recordatorio del escenario.

### 6.2 Escribe el ADR

Edita `/tmp/dkr-09-strategy/tag-strategy.md`. **Deben existir** (nombres literales de las secciones; el validador los busca):

```markdown
# Tag strategy — platform/orders-api (ADR)

## Context
Resume el escenario con tus palabras.

## Decision: immutable tags
Lista exacta de tags inmutables que publicaras, con el formato (p.ej. `vX.Y.Z`, `sha-<7>`).

## Decision: mutable tags
Lista exacta de tags mutables (p.ej. `vX.Y`, `vX`, `latest`, `edge`, `pr-<N>`).

## Decision: production pin
Como referencia produccion la imagen (tag? digest? ambos?). Como fluye del build al deploy.

## Decision: staging and dev pin
Como referencian staging y dev. Diferencias con prod.

## Decision: base image rotation
Como mantienes `FROM python:3.12-slim`: pin a digest? rotacion manual? Renovate/Dependabot? cadencia?

## Decision: latest
Que significa `latest` en tu estrategia (si existe) y quien lo consume.

## Rationale
Dos a cinco parrafos justificando el conjunto. Debe tocar: reproducibilidad,
trazabilidad para SOC 2, rate-limits, preview environments, y riesgo operacional.

## Trade-offs
Que pierdes con esta estrategia y que alternativas descartaste.
```

Longitud razonable: 400–900 palabras. No es un ensayo, es un ADR.

### 6.3 Valida la estructura

```bash
bash courses/docker/09-registries-tags-and-digests/activities/02-tag-strategy-design/tests/validate.sh /tmp/dkr-09-strategy
```

El validador comprueba, sin juzgar las decisiones:

1. `tag-strategy.md` existe.
2. Tiene las **nueve secciones** del esqueleto (match por título).
3. Las secciones de decisión tienen **contenido no trivial** (más de 20 caracteres no-whitespace, no son solo el placeholder).
4. En la sección `Rationale` aparecen al menos **tres** de estos conceptos clave: `reproducibilidad`, `trazabilidad`, `digest`, `rate-limit` (o `rate limit`), `preview`, `rollback`, `SOC`.

## 7. Resultado esperado

- `/tmp/dkr-09-strategy/tag-strategy.md` existe con todas las secciones completadas.
- Las decisiones son **explícitas** (listas concretas de tags, no "varios tags").
- El rationale cubre los temas listados.

## 8. Criterios de aceptación

- [ ] Archivo `tag-strategy.md` existe.
- [ ] Las nueve secciones están presentes con sus títulos exactos.
- [ ] Cada "Decision" tiene al menos una decisión concreta (no vacía ni "TBD").
- [ ] El rationale menciona ≥ 3 conceptos clave (reproducibilidad, trazabilidad, digest, rate-limit, preview, rollback, SOC).
- [ ] `tests/validate.sh` termina con `OK`.

## 9. Validación

```bash
bash courses/docker/09-registries-tags-and-digests/activities/02-tag-strategy-design/tests/validate.sh /tmp/dkr-09-strategy
```

## 10. Preguntas de reflexión

1. ¿Qué cambiarías de tu ADR si la base no fuera `python:3.12-slim` sino `cgr.dev/chainguard/python:3.12` (que ya se publica pinneada por digest y se rebuildea diariamente con rotación automática)?
2. ¿Qué cambia si en lugar de Argo CD usas un `kubectl set image` manual desde CI? ¿Tiene sentido el pin por digest? ¿Por qué?
3. Si SOC 2 pide "demostrar en una auditoría qué imagen corrió el 15 de marzo", ¿cómo te ayuda tu política? ¿Y cómo te ayudaría *más* si firmaras cada release con cosign (ver `dkr-14`)?
4. ¿Por qué `latest` sigue siendo útil incluso cuando prod no lo consume?
5. ¿Qué pasa si el equipo de frontend consume la imagen por `v1` en vez de `v1.2.3`? ¿Es un bug suyo o un bug tuyo?

## 11. Extensiones (opcional)

- **E1** — Añade una sección "Immutable tags en el registry" explicando si activarías esa feature en GHCR y por qué.
- **E2** — Añade una sección "Supply chain" con qué firmarías (cosign keyless), qué SBOM (syft), y qué attestations (SLSA provenance). (Puedes basarte en `dkr-14`.)
- **E3** — Escribe el workflow `.github/workflows/publish.yml` que implementa tu política con `docker/metadata-action`.

## 12. Limpieza

```bash
rm -rf /tmp/dkr-09-strategy
```
