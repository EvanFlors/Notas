# Ejemplo 01 — Library chart con helpers compartidos

Un library chart (`platform-lib`) que exporta helpers de labels/selectors/nombre, consumido por un chart application (`consumer-chart`). Al final verás que `helm template` sobre la lib **no produce manifests** y sobre el consumer **sí**.

## Prerrequisitos

- `helm` ≥ 3.13

```bash
helm version --short
```

## Qué hay aquí

```
examples/01-library-chart-shared-helpers/
├── platform-lib/
│   ├── Chart.yaml           (type: library)
│   └── templates/_helpers.tpl
├── consumer-chart/
│   ├── Chart.yaml           (type: application, depends on platform-lib)
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       └── service.yaml
└── run.sh                   (smoke script: dep build + template)
```

## Pasos

```bash
cd /Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy/courses/helm/10-platform-patterns-library-charts-argo-flux-and-kustomize-boundary/examples/01-library-chart-shared-helpers

# 1. Un intento de "instalar" la library — Helm no renderiza nada util.
helm template probe ./platform-lib

# 2. Build dependencies del consumer (copia platform-lib bajo consumer-chart/charts/).
helm dependency build ./consumer-chart

# 3. Render del consumer. Deberias ver labels/name consistentes aportados por la lib.
helm template demo ./consumer-chart

# 4. Smoke script
bash run.sh
```

## Lectura mental

- `platform-lib/Chart.yaml` declara `type: library`. `helm install` sobre esto es un no-op: no hay recursos.
- `_helpers.tpl` solo contiene `{{- define ... -}}`. Nada que renderizar.
- El consumer lo declara en `dependencies:` con `repository: "file://../platform-lib"`. `helm dependency build` copia el chart bajo `consumer-chart/charts/platform-lib/`.
- El consumer invoca los helpers con `{{ include "platform.labels" . }}`. Siempre `include`, no `template`, para poder pipear a `nindent`.

## Limpieza

```bash
rm -rf consumer-chart/charts consumer-chart/Chart.lock
```
