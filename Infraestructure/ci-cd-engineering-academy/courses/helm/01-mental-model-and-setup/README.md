# helm-01 — Modelo mental y setup

## Identificación

- **ID:** `helm-01-mental-model-and-setup`
- **Curso:** `helm`
- **Nivel:** fundamentos
- **Duración estimada:** 2 h
- **Prerrequisitos:** curso **kubernetes** ≥ Nivel 2 (necesario para entender qué está Helm generando). YAML a nivel operativo.

## Objetivo

Construir el **modelo mental correcto** de Helm *antes* de instalar nada propio: qué es un **chart**, qué es una **release**, qué es un **repository**, y por qué `values.yaml` **es** la API pública de un chart. Entender por qué Helm 3 eliminó Tiller y qué cambia operacionalmente respecto a Helm 2. Poner un entorno funcional con el binario `helm` y los comandos exploratorios (`helm env`, `helm version`, `helm search hub|repo`, `helm show chart|values|readme`).

Al terminar este módulo deberías poder, **sin consultar docs**:

- Definir con tus palabras **chart**, **release**, **revision**, **repository** y **values**.
- Explicar por qué un *package manager* tiene sentido en Kubernetes (y por qué `kubectl apply -f` no basta a escala).
- Explicar por qué **Tiller** fue abandonado y qué significa que Helm 3 renderice **en el cliente**.
- Usar `helm search hub` y `helm show values` para evaluar un chart de terceros antes de instalarlo.
- Argumentar por qué `values.yaml` **es** el contrato de un chart (y por qué `values.schema.json` lo formaliza).

Este módulo es deliberadamente **"antes de instalar nada propio"**: no se escribe un chart todavía; se **consume información** sobre charts ajenos y se afianza el vocabulario. La instalación de releases (`helm install` / `upgrade` / `rollback`) es `helm-02`.

## Alcance

Este módulo cubre:

- Por qué un *package manager* para Kubernetes: límites de `kubectl apply -f` sobre árboles de YAML por entorno.
- Los **cuatro conceptos**: chart, release, revision, repository (+ values).
- **Helm 3 vs Helm 2**: por qué Tiller era un problema (singleton server-side con permisos amplios) y qué cambió al mover el rendering al cliente.
- Instalación del binario `helm` (binario único, Go, sin daemon).
- Comandos exploratorios **sin cluster**: `helm version`, `helm env`, `helm search hub`, `helm search repo`, `helm show chart|values|readme`.
- `values.yaml` como la **API pública** del chart.

Lo que **no** cubre (vendrá después):

- `helm install` / `upgrade` / `rollback` / `uninstall` sobre un cluster → `helm-02`.
- Escribir un chart propio, `Chart.yaml`, `templates/`, `_helpers.tpl` → `helm-03`.
- Templating en profundidad (Sprig, `include`, `required`) → `helm-04`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (≈ 1,5 h).
- **`examples/`** — ejemplos conceptuales / sin cluster:
  - `01-helm-search-and-show/` — recorrido comentado por `helm search hub`, `helm search repo` y `helm show chart|values|readme` sobre un chart popular.
  - `02-tiller-vs-helm3-notes/` — contexto histórico: qué era Tiller, por qué era un riesgo, qué resuelve Helm 3 al eliminarlo.
- **`activities/`**:
  - `01-install-helm-and-explore/` — **guided-lab**. Instala `helm`, imprime `version`/`env`, añade un repo, busca charts y produce un `NOTES.md`.
  - `02-read-values-of-popular-chart/` — **independent**. Analiza `values.yaml` de **3 charts populares** y produce un `ANALYSIS.md` argumentando por qué `values` **es** la interfaz del chart.
- **`resources/links.md`** — docs oficiales, Artifact Hub, lecturas de referencia.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar sin consultar: chart, release, revision, repository, values. Justificar por qué `values.yaml` es la API del chart. |
| Operativa | Instalar `helm`; usar `search hub|repo` y `show chart|values|readme` para evaluar un chart; leer `Chart.yaml` y mapear sus campos a conceptos. |
| Arquitectónica | Argumentar por qué Tiller fue un problema de seguridad; explicar la decisión de Helm 3 (render en el cliente, apply contra el API server como cualquier otro usuario). |

## Entregables

- `NOTES.md` de la actividad 01: `helm version`, `helm env`, repo añadido, 5 charts encontrados en Artifact Hub.
- `ANALYSIS.md` de la actividad 02: notas con la "API" (`values`) de **3 charts populares** (ingress-nginx, cert-manager, kube-prometheus-stack u otros equivalentes) con secciones por chart y valores específicos documentados.

## Criterios de evaluación

- Lección leída y preguntas de evaluación respondidas (`theory/lesson.md` §12).
- Actividad 01 entregada y `tests/validate.sh` pasa (estructural).
- Actividad 02 entregada: `ANALYSIS.md` con **una sección por chart**, **al menos 5 valores** específicos documentados por chart (nombre, tipo, default, para qué sirve), y un párrafo final **justificando por qué `values.yaml` es la interfaz del chart**.
- Saber contestar "¿por qué desapareció Tiller?" sin dudar.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Recorre `examples/01-helm-search-and-show/` — mapea el output a los conceptos.
3. Recorre `examples/02-tiller-vs-helm3-notes/` — fija el porqué del cambio Helm 2 → 3.
4. Haz la actividad `01-install-helm-and-explore/` — tu entorno queda listo.
5. Haz la actividad `02-read-values-of-popular-chart/` — practica criterio profesional al evaluar charts.
6. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `helm-02-consume-charts-install-upgrade-rollback`: operar el ciclo de vida de releases con charts de terceros (install, upgrade, rollback, uninstall) sobre un cluster local.
