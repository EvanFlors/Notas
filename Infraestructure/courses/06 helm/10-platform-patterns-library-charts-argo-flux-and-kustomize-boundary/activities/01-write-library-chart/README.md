# Actividad 01 — Escribir un library chart y consumirlo

## 1. Identificación

- **ID:** `helm-10-01-write-library-chart`
- **Tecnología:** `helm`
- **Módulo:** `helm-10-platform-patterns-library-charts-argo-flux-and-kustomize-boundary`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab

## 2. Contexto

Tu plataforma tiene 12 charts internos y los `_helpers.tpl` están duplicados. Los labels divergen entre equipos, un chart escribe `app.kubernetes.io/instance` y otro `app.k8s.io/instance`, y los nombres pasan de 63 chars en apps con nombre largo. Vas a resolverlo escribiendo un **library chart** (`platform-lib`) que centraliza helpers y conectarlo a una app de ejemplo (`demo-app`).

## 3. Objetivos

- Declarar un chart como `type: library` y comprobar que *no* produce manifests.
- Escribir `define` blocks para `platform.name`, `platform.fullname`, `platform.labels` y `platform.selectorLabels`.
- Declarar la dependencia desde `demo-app/Chart.yaml` usando `repository: "file://../platform-lib"`.
- Correr `helm dependency build` y `helm template` sin errores.
- Verificar que los labels compartidos aparecen en el output.

## 4. Prerrequisitos

- `helm` ≥ 3.13 (los ejemplos funcionan también con Helm 4.x).
- Lección `theory/lesson.md`, §2 y §3.
- Ejemplo `examples/01-library-chart-shared-helpers/` recorrido.

Sin costes cloud: todo local.

## 5. Instrucciones

Trabaja en `starter/`. Al terminar, debe pasar `tests/validate.sh`.

### 5.1 Completa `starter/platform-lib/Chart.yaml`

Pon `apiVersion: v2`, `name: platform-lib`, `type: library`, `version: 0.1.0`.

### 5.2 Completa `starter/platform-lib/templates/_helpers.tpl`

Define **cuatro** bloques:

- `platform.name` — nombre corto (chart name o `.Values.nameOverride`), truncado a 63 chars.
- `platform.fullname` — `<release>-<name>`, truncado a 63 chars.
- `platform.labels` — set estándar de labels Kubernetes + `platform.example.com/owner` desde `.Values.owner`.
- `platform.selectorLabels` — `app.kubernetes.io/name` y `app.kubernetes.io/instance` (subset estable de labels).

### 5.3 Completa `starter/demo-app/Chart.yaml`

- `type: application`
- `dependencies:` con un entry `name: platform-lib`, `version: 0.1.0`, `repository: "file://../platform-lib"`.

### 5.4 Completa `starter/demo-app/templates/deployment.yaml`

Usa los helpers:

```yaml
metadata:
  name: {{ include "platform.fullname" . }}
  labels:
    {{- include "platform.labels" . | nindent 4 }}
```

### 5.5 Build + render

```bash
cd starter
helm dependency build ./demo-app
helm template demo ./demo-app
```

### 5.6 Valida

```bash
bash tests/validate.sh
```

Debe terminar en `OK`.

## 6. Resultado esperado

- `platform-lib` no renderiza manifests (`helm template probe ./platform-lib` imprime vacío).
- `helm dependency build ./demo-app` copia la lib bajo `demo-app/charts/`.
- `helm template demo ./demo-app` incluye:
  - `app.kubernetes.io/managed-by: Helm`
  - `platform.example.com/owner: "team-platform"` (desde `values.yaml`)
  - `name: demo-demo-app` (desde `platform.fullname`)

## 7. Criterios de aceptación

- [ ] `platform-lib/Chart.yaml` declara `type: library`.
- [ ] 4 `define` bloques en `_helpers.tpl`.
- [ ] `demo-app/Chart.yaml` depende de `platform-lib` con `file://`.
- [ ] `demo-app/templates/deployment.yaml` usa `include` + `nindent`, nunca `template`.
- [ ] `tests/validate.sh` termina en `OK`.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador comprueba estructura, builds, renderiza el consumer y busca los labels esperados.

## 9. Preguntas de reflexión

1. ¿Por qué `include` y no `template` cuando el helper tiene que ser indentado?
2. ¿Qué pasa si cambias `type: library` por `type: application` en `platform-lib`?
3. ¿Qué estrategia usarías para versionar `platform-lib` en una organización con 20 consumidores?
4. ¿Qué cosas **nunca** meterías en un library chart y por qué?
5. Si publicas la lib a un OCI registry, ¿cómo cambia la línea `repository:` del consumer?

## 10. Extensiones

- **E1** — Añade un helper `platform.probes` que genere liveness/readiness HTTP configurables por `.Values.probes.*`.
- **E2** — Añade `values.schema.json` al `demo-app` que exija `owner` y rechace valores extra.
- **E3** — Simula un breaking change: cambia la firma de `platform.labels` (quita un label), bump a MAJOR (`1.0.0`) y escribe un `MIGRATING.md`.

## 11. Limpieza

```bash
rm -rf starter/demo-app/charts starter/demo-app/Chart.lock
```
