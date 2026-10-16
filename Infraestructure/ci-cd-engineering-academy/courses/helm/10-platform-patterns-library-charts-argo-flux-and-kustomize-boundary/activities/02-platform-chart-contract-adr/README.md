# Actividad 02 — ADR: contrato del chart de plataforma y frontera Helm/Kustomize/operador

## 1. Identificación

- **ID:** `helm-10-02-platform-chart-contract-adr`
- **Tecnología:** `helm`
- **Módulo:** `helm-10-platform-patterns-library-charts-argo-flux-and-kustomize-boundary`
- **Dificultad:** advanced
- **Duración estimada:** 75–120 min
- **Tipo:** architecture (entregable escrito, independiente)

## 2. Contexto

Tu plataforma usa Helm para casi todo. Hay charts internos duplicados, cada equipo versiona a su manera, los hooks de Helm se portan mal con Argo CD, y acabas de descubrir que un chart complejo (PostgreSQL casero) debería ser un operador. Es momento de **fijar el contrato**.

El validador no juzga qué elecciones hiciste — hay varias respuestas razonables — : verifica que estén **tomadas, justificadas contra alternativas, con política de versionado explícita y con triggers de revisión**.

## 3. Objetivos

- Definir el **contrato del golden chart** de plataforma: qué `values` acepta, qué recursos genera, qué garantiza, qué espera del consumidor.
- Decidir **Helm vs Kustomize vs operador** para 3 escenarios reales.
- Fijar la **política de versionado** del chart interno: SemVer, deprecation window, migration guides.
- Documentar la integración con **GitOps** (Argo CD o Flux) y sus trampas.
- Nombrar alternativas descartadas, consecuencias, riesgos y triggers de revisión.

## 4. Prerrequisitos

- Lección `theory/lesson.md` leída, especialmente §3, §4–§5, §7–§9, §11.
- Ejemplos 01–03 recorridos (al menos conceptualmente).
- Haber completado `helm-07`, `helm-08`, `helm-09`.

Sin costes cloud: todo es un documento Markdown.

## 5. Instrucciones

### 5.1 Escenario asignado

> **Organización:** scaleup SaaS B2B. 90 ingenieros en 11 equipos de producto + 4 FTE de plataforma. 3 clusters EKS (dev, stg, prod) y kind local por dev.
> **Workloads en Helm hoy:** ~ 55 charts internos. ~ 70% son servicios HTTP/gRPC Go/Python casi idénticos. ~ 15% son workers de colas (Celery/RQ). El resto, "específicos" (uno es un PostgreSQL "casero" con un StatefulSet + Jobs de backup, otro es un gateway Envoy custom).
> **Entrega:** cada equipo instala con `helm upgrade --install` desde su propio pipeline. Hay drift entre lo que piensa Helm que está desplegado y lo que hay en el cluster (operadores los modifican, kubectl edit ocasional).
> **Lo que la plataforma ya ofrece:** `kube-prometheus-stack`, `cert-manager`, `ingress-nginx`, `external-dns`, Argo CD recién instalado (todavía sin usar en serio).
> **Dolores:**
>  - 55 copias de `_helpers.tpl`, divergen.
>  - Upgrades frágiles por hooks mal usados.
>  - El "PostgreSQL casero" ha roto producción dos veces por backups fallidos silenciosos.
>  - Nadie sabe qué versión de qué chart tiene en qué cluster.
> **Restricciones:** 2 trimestres para la primera versión del contrato.

**Tu misión:** proponer el **contrato del chart de plataforma** y defender la frontera Helm/Kustomize/operador en formato ADR.

### 5.2 Entregable

Edita el archivo:

```
starter/ADR-001-platform-chart-contract.md
```

Reemplaza los `TODO:` por contenido real. **No borres las cabeceras de sección** — el validador las espera literalmente.

### 5.3 Estructura mínima (secciones obligatorias)

Las siguientes cabeceras deben aparecer textualmente:

- `# ADR-001: Platform Chart Contract`
- `## Status`
- `## Context`
- `## Decisions`
- `## Chart Contract`
- `## Versioning Policy`
- `## GitOps Integration`
- `## Boundary: Helm vs Kustomize vs Operator`
- `## Alternatives Considered`
- `## Consequences`
- `## Risks and Mitigations`
- `## Review Triggers`

Y además:

- **4 bloques de decisión explícitos** en `## Decisions`, uno por cada eje. Cada uno debe empezar por `We will adopt` seguido de la opción, cubriendo:
  - **library chart**: `platform-lib library chart` (se **espera** esta elección para no copiar helpers).
  - **golden chart**: `platform-app golden chart`, `one chart per app`, o `golden chart with escape hatch` (híbrido).
  - **GitOps engine**: `Argo CD` o `Flux`.
  - **versioning policy**: `SemVer with deprecation window` (se **espera** esta forma; cualquier otra debe justificarse con fuerza).
- **En `## Chart Contract`**: dos listados que describan **qué ofrece** el chart (los recursos y defaults que materializa) y **qué espera** del consumidor (campos obligatorios en `values`, probes, labels, imágenes firmadas…). Al menos 6 bullets en total.
- **En `## Versioning Policy`**: debe mencionar `MAJOR`, `MINOR`, `PATCH` y la palabra `deprecation`. Debe aparecer también `MIGRATING.md` o `migration guide`.
- **En `## GitOps Integration`**: debe mencionar al menos una trampa conocida (buscamos la palabra `hook`, `release name`, o `releaseName`).
- **En `## Boundary: Helm vs Kustomize vs Operator`**: **3 escenarios** descritos como bullets. Cada bullet debe ser una decisión explícita (`Helm`, `Kustomize`, o `Operator`) con una frase de justificación. El validador exige la palabra `Operator` al menos una vez (recuerda el PostgreSQL casero).
- **Al menos 3 alternativas descartadas** en `## Alternatives Considered`.
- **Al menos 4 consecuencias** en `## Consequences`.
- **Al menos 3 riesgos con mitigación** en `## Risks and Mitigations` (la palabra `Mitigation` debe aparecer ≥ 3 veces).
- **Al menos 2 criterios** en `## Review Triggers`.

Longitud razonable: 800–1500 palabras.

### 5.4 Validar

```bash
bash tests/validate.sh starter/ADR-001-platform-chart-contract.md
```

Debe terminar en `OK`.

### 5.5 (Opcional) comparar con la referencia

Lee `solution/ADR-reference.md`. Es **una** respuesta razonada, no la única.

## 6. Resultado esperado

- `starter/ADR-001-platform-chart-contract.md` con todas las secciones y decisiones.
- Validador en `OK`.
- Puedes defender tus 3 decisiones de frontera (Helm/Kustomize/operador) en una revisión de arquitectura.

## 7. Criterios de aceptación

- [ ] ADR con las 12 secciones obligatorias.
- [ ] 4 decisiones explícitas (library chart, golden chart, GitOps engine, versioning).
- [ ] Chart contract con "offers" y "expects" explícitos.
- [ ] Política de versionado con SemVer + deprecation window + migration guides.
- [ ] GitOps integration menciona al menos una trampa conocida.
- [ ] 3 decisiones de frontera (al menos una `Operator`).
- [ ] 3+ alternativas descartadas, 4+ consecuencias, 3+ riesgos con mitigación, 2+ review triggers.
- [ ] `tests/validate.sh` pasa.
- [ ] ≥ 800 palabras.

## 8. Validación

```bash
bash tests/validate.sh starter/ADR-001-platform-chart-contract.md
```

Comprueba **estructura y presencia**, no corrección semántica (eso lo evalúa un par o un instructor).

## 9. Preguntas de reflexión

1. ¿Qué datos del escenario pesaron más en elegir Argo CD vs Flux?
2. ¿Qué política de versionado necesitas que 11 equipos distintos consuman el chart sin romperse?
3. ¿Qué 3 criterios usarías para rechazar la petición "añade este `value` nuevo al golden chart" de un equipo?
4. ¿Qué pasaría si *tú* decides mantener el PostgreSQL casero como Helm en vez de operador — a los 12 meses?
5. ¿Cómo deprecarías el helper `platform.labels` v0.x cuando pases a v1 con un breaking change?

## 10. Extensiones

- **E1** — Dibuja un diagrama ASCII del flujo PR → GitOps → cluster para una app que consume el golden chart.
- **E2** — Añade `ADR-002` que elija el formato de distribución del chart (OCI firmado con cosign) y la política de retención.
- **E3** — Escribe un `MIGRATING.md` de ejemplo para pasar del helper `platform.labels` v0 a v1.

## 11. Limpieza

```bash
# Volver al starter inicial
git checkout -- starter/ADR-001-platform-chart-contract.md
```
