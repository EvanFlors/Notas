# Actividad 02 — ADR de mínimo privilegio sobre un project `*/*`

## 1. Identificación

- **ID:** `argo-06-02-least-privilege-rbac-adr`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `06-projects-rbac-and-boundaries`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** independent

## 2. Contexto

Heredas un `AppProject` llamado `legacy-everything` que un compañero creó "para empezar rápido" hace un año. Lo tiene todo abierto: `sourceRepos: ['*']`, `destinations: [{server: '*', namespace: '*'}]`, `clusterResourceWhitelist: [{group: '*', kind: '*'}]`, un role `admin` con un token emitido en origen y nunca rotado.

Hoy hay cuatro Applications en producción vivas detrás de ese project. **No puedes romperlas**. Tu trabajo:

1. **Auditar** qué permisos realmente usa cada Application.
2. **Diseñar** la restricción mínima suficiente (`AppProject` o varios).
3. **Escribir un ADR** (`Architecture Decision Record`) corto justificando cada restricción.
4. **Entregar** los manifests nuevos que, de aplicarse, no romperían ninguna Application existente.

Esta actividad es independent: no hay solución guiada paso a paso. Hay una `solution/ADR-reference.md` para auto-evaluarte **después** de entregar lo tuyo.

## 3. Objetivos

Al terminar deberías poder:

- Auditar un `AppProject` real identificando los 7 puntos típicos (sourceRepos, destinations, cluster/namespace whitelists, roles, tokens, orphanedResources).
- Inferir el permiso mínimo necesario a partir de las Applications existentes.
- Escribir un ADR con contexto, decisión, consecuencias y alternativas descartadas.
- Diferenciar restricciones del `AppProject` de restricciones de K8s RBAC en el cluster target.

## 4. Prerrequisitos

- Haber completado la actividad 01 de este módulo.
- `yq` (v4+) o `jq` y `python3` para parsear YAML/JSON.
- `bash`.

**Costos:** 0 €. Esta actividad **no** requiere cluster. Trabajas con los manifests de `starter/`.

## 5. Instrucciones

### 5.1 Preparar el entorno

```bash
mkdir -p /tmp/argo-06-02
cp -r <ruta-de-la-actividad>/starter/* /tmp/argo-06-02/
cd /tmp/argo-06-02
```

Verás:

- `legacy-everything.yaml` — el project laxo heredado.
- `apps/` — cuatro Applications reales que usan ese project:
  - `app-platform-monitoring.yaml`
  - `app-team-payments-api.yaml`
  - `app-team-payments-worker.yaml`
  - `app-team-checkout-ui.yaml`
- `audit-notes.md` — una plantilla donde registrarás tus hallazgos.

### 5.2 Auditar

Produce `/tmp/argo-06-02/AUDIT.md` donde para cada Application respondas:

| Pregunta | Dónde mirar |
|----------|-------------|
| ¿Qué `repoURL` usa? | `spec.source.repoURL` |
| ¿Qué cluster/namespace destino? | `spec.destination` |
| ¿Qué `kind` de recursos crea? | `spec.source.path` → inferir del contenido (anota tu suposición si no lo ves) |
| ¿Necesita algún recurso cluster-scoped? | Mira si crea `Namespace`, `ClusterRole`, `CRD`, etc. — en el starter cada Application lo declara en un comentario `# Creates: ...` para facilitar la auditoría |

### 5.3 Diseñar el nuevo modelo

Decide (y justifícalo en el ADR):

- ¿Un solo `AppProject` acotado basta?
- ¿Vale la pena romper en **varios** (uno por equipo)?
- ¿Qué `sourceRepos`, `destinations`, whitelists mínimos resultan?
- ¿Qué pasa con el role `admin` del project original? ¿Qué roles nuevos propones?
- ¿Qué pasa con el token "token-vieja-produccion" que ya existe?

Entrega los nuevos manifests en `/tmp/argo-06-02/proposed/`:

- Un `*.yaml` por `AppProject` propuesto.
- Un `README.md` corto que mapee cada Application existente al nuevo project al que debería pasar.

### 5.4 Escribir el ADR

Produce `/tmp/argo-06-02/ADR-001-least-privilege-projects.md` con la estructura:

```
# ADR-001: Migración de legacy-everything a projects acotados

## Status
Proposed | Accepted | ...

## Context
<por qué existe el problema; evidencia del audit>

## Decision
<qué hacemos exactamente; cuántos projects, con qué contornos>

## Consequences
<positivas y negativas; qué cambia para cada equipo; qué hay que coordinar>

## Alternatives considered
<2–3 opciones descartadas y por qué>

## Migration plan
<pasos concretos; cómo evitamos downtime; cómo revocamos el token legacy>
```

### 5.5 Validar

```bash
bash tests/validate.sh
```

El script valida **estructuralmente** (presencia de secciones y archivos, no corrección semántica). La corrección semántica la haces tú contra `solution/ADR-reference.md`.

## 6. Resultado esperado

- `AUDIT.md` con las 4 Applications auditadas.
- Directorio `proposed/` con nuevos `AppProject` manifests + README de mapeo.
- `ADR-001-least-privilege-projects.md` con las 6 secciones.
- `tests/validate.sh` termina con `OK`.

## 7. Criterios de aceptación

- [ ] El AUDIT identifica para cada Application: repo, destino, recursos.
- [ ] La propuesta usa **al menos 2** `AppProject` nuevos (o justifica por qué uno solo basta).
- [ ] Ningún `AppProject` propuesto tiene `*` en `sourceRepos` ni `destinations`.
- [ ] El ADR tiene las 6 secciones (Status, Context, Decision, Consequences, Alternatives, Migration plan).
- [ ] El Migration plan menciona explícitamente la revocación del token legacy y una ventana de validación.
- [ ] (Deseable) El ADR documenta qué permisos permanecerían en el project `default` tras la migración.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

Añádelas al final del ADR o en `REFLECTION.md`:

1. Si una de las Applications cambia su `source.path` a un chart que ahora necesita crear un `CRD`, ¿qué parte de tu diseño rompe y cómo la ajustas?
2. ¿Por qué un ADR es más valioso que simplemente aplicar los manifests y seguir? ¿Qué pasa cuando el próximo compañero vea estos projects dentro de 6 meses?
3. ¿Qué papel juega el **cluster RBAC** aquí? Si tu nuevo project es perfecto pero el ServiceAccount de Argo CD en el cluster target es `cluster-admin`, ¿qué sigue siendo riesgoso?
4. ¿Cómo detectarías *automáticamente* en CI que alguien introdujo un project con `*/*` otra vez?

## 10. Extensiones

- **E1** — Escribe un script `audit.sh` que corra en CI (bash + `yq`) y falle si cualquier `AppProject` en el repo tiene `*` en `sourceRepos` o `destinations`.
- **E2** — Propón un `signatureKeys` para el project crítico (payments) y describe cómo distribuirías la clave pública entre firmantes.
- **E3** — Diseña el `argocd-rbac-cm` que acompañaría a tu propuesta: qué roles, qué grupos OIDC y qué `policy.default`.

## 11. Limpieza

```bash
rm -rf /tmp/argo-06-02
```

No se creó nada en el cluster.
