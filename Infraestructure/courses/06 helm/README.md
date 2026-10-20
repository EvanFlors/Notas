# Curso: Helm

Roadmap especializado #8. Package manager y motor de templating/release para Kubernetes. Curso deliberadamente **compacto**: Helm cubre un dominio acotado y su valor está en el detalle fino, no en la amplitud.

## 1. Introducción

### Qué es

**Helm** es una herramienta que empaqueta aplicaciones Kubernetes como **charts** (plantillas + metadatos + valores por defecto) y las instala en el cluster como **releases** (instancias versionadas de un chart). Opera siempre contra el **API server** del cluster y, desde Helm 3, no requiere un componente server-side (desapareció Tiller).

Importante separar cuatro conceptos:
- **Chart** — artefacto empaquetado (tar `.tgz` con `Chart.yaml`, `templates/`, `values.yaml`, `charts/`).
- **Release** — instancia de un chart aplicada a un cluster y namespace, con nombre único, revisión y valores efectivos.
- **Values** — datos que parametrizan los templates (defaults del chart + overrides del usuario).
- **Repository** — índice de charts publicados (HTTP tradicional o **OCI registry** desde Helm 3.8).

### Historia (síntesis)

- **2015** — Deis libera Helm 1.
- **2016** — Kubernetes adopta el proyecto; Helm 2 introduce **Tiller** (componente in-cluster con permisos amplios — fuente histórica de problemas de seguridad).
- **2019** — **Helm 3** elimina Tiller, el estado de releases se guarda en Secrets/ConfigMaps del namespace del release.
- **2022** — Soporte de **OCI registries** como forma preferida de publicar/consumir charts (reemplaza paulatinamente a `index.yaml` HTTP).
- **2024+** — Mejoras en experiencias de prueba (`helm unittest`), integración más limpia con Argo CD/Flux, cambios de UX menores.

### Problemas que resuelve

- **Reutilización** de manifests complejos sin copiar-pegar YAML entre entornos.
- **Parametrización** por entorno/cliente/tenant mediante `values.yaml` + overrides.
- **Release management**: instalar, upgrade, rollback, uninstall con revisiones.
- **Distribución**: un chart publicado en un registry es una unidad consumible pública o privada.
- **Composición**: charts umbrella que agregan sub-charts (base + app + dependencies).

### Casos de uso

- Instalar software de terceros maduro (ingress-nginx, cert-manager, Prometheus Operator, Argo CD, …).
- Empaquetar servicios internos para distribuirlos a múltiples equipos/clusters.
- Base para GitOps con **Argo CD** o **Flux** (ambos leen Helm charts como fuente).
- Templating puntual (`helm template`) para generar YAML sin usar el release lifecycle.

### Arquitectura general

```
┌─────────────────────────────────────┐
│  Chart (tgz)                        │
│   Chart.yaml                        │
│   values.yaml           ← defaults  │
│   templates/*.yaml      ← Go tmpl   │
│   templates/_helpers.tpl            │
│   charts/   (deps)                  │
│   Chart.lock                        │
└─────────────────────────────────────┘
            │
            │ helm install/upgrade (--values, --set)
            ▼
┌─────────────────────────────────────┐
│  Rendering en el cliente            │
│   templates + values → manifests    │
│   (puro YAML, sin Tiller)           │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  API server del cluster             │
│   apply con server-side apply       │
│   release storage en Secret o CM    │
└─────────────────────────────────────┘
```

### Alternativas

- **Kustomize** — overlays declarativos sobre YAML base, *sin* templating. Integrado en `kubectl -k`. Preferido por quienes rechazan el string-templating.
- **jsonnet / ksonnet** — lenguaje de configuración; curva de aprendizaje mayor; menos adoptado.
- **cdk8s** — generar manifests desde TypeScript/Python/Go/Java.
- **Carvel ytt** — templating YAML-aware (VMware).
- **Operadores** (CRDs) — para software con operación compleja (p. ej. CloudNativePG, Strimzi), un operador supera a un chart cuando la lógica de reconciliación es rica.

### Ventajas / limitaciones

**Ventajas**: estándar de facto, enorme marketplace de charts (Artifact Hub), integración limpia con Argo CD/Flux, release management maduro.

**Limitaciones / riesgos**:
- **Go templates sobre YAML** es la crítica más repetida: errores de indentación, debugging incómodo, poca seguridad de tipos.
- Charts "mega-genéricos" se vuelven inmantenibles (over-abstraction).
- Diffing entre revisiones es menos obvio que con Kustomize overlays.
- Hooks mal usados pueden dejar el cluster en estados raros.
- Dependencias transitivas y "umbrella charts" grandes aumentan el blast radius de un upgrade.
- `values.yaml` sin **JSON Schema** (`values.schema.json`) deja la "API" del chart sin validación.

### Relación con el programa

- Herramienta principal para instalar software base del cluster (ingress, cert-manager, Prometheus Operator, Argo CD mismo).
- Base para empaquetar los servicios del **capstone**.
- Fuente de verdad consumida por **Argo CD** (curso siguiente) para GitOps.
- Punto donde se aplican políticas DevSecOps (firma del chart con provenance, OCI).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Curso **kubernetes** ≥ Nivel 2 (necesario para entender qué está Helm generando). YAML a nivel operativo. |
| Recomendados | Nociones básicas de Go templates (no es imprescindible pero ayuda). Curso **docker** completo (OCI registries). |
| Complementarios | Curso **github-actions** para publicación de charts a OCI/GHCR. |

## 3. Organización (4 niveles)

El curso tiene **10 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (2): modelo mental y setup, consumo de charts existentes (install/upgrade/rollback/uninstall).
- **Nivel 2 — Intermedio** (4): anatomía de un chart propio, templating en profundidad, values y overrides, dependencias y subcharts.
- **Nivel 3 — Avanzado** (3): lifecycle (hooks, tests, atomic/wait), repositorios y publicación (HTTP vs OCI, firma/provenance), testing (lint, template, unittest, chart-testing).
- **Nivel 4 — Producción empresarial** (1): platform patterns (library charts, umbrella vs app charts, Helm + Argo CD/Flux, cuándo migrar a/desde Kustomize).

## 4. Entregables del curso

- Chart propio para la app del capstone con `values.schema.json`, probes, PDB, HPA opcional, NetworkPolicy, ServiceMonitor y hooks de migration.
- Umbrella chart que combina app + Postgres (vía dependencia a un chart maduro) para entornos dev locales.
- Chart publicado a **GHCR como OCI**, firmado con provenance.
- Pipeline de GitHub Actions que valida (`lint`, `template`, `unittest`, `chart-testing`) e instala el chart en kind.

## 5. Evaluación

- **Conceptual**: diferenciar chart, release, revisión; explicar la secuencia completa de `helm install` desde la CLI hasta el apply en el API server; cuándo Helm vs Kustomize vs operador.
- **Operativa**: escribir un chart desde cero; depurar un `helm upgrade` que falla; usar hooks correctamente; publicar y consumir chart OCI firmado.
- **Arquitectónica**: diseñar la frontera de un chart (qué es *values*, qué es *template*); evaluar umbrella vs charts separados; integrar con Argo CD con el patrón correcto.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial `helm.sh/docs`.
- *Chart Best Practices Guide* oficial.
- `helm/charts` deprecado — Artifact Hub (`artifacthub.io`) como índice público.
- Soporte OCI oficial (`helm.sh/docs/topics/registries/`).
- `helm-unittest` plugin.
- `chart-testing` (`ct`) usado por el proyecto Kubernetes.
- Integración con Argo CD (chart `helm:` source) y Flux (HelmRelease CRD).
