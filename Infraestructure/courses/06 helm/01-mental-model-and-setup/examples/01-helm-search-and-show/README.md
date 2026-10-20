# Ejemplo 01 — `helm search` y `helm show`

## Concepto que demuestra

Cómo **evaluar** un chart de terceros **sin instalar nada**: dónde buscarlo (`helm search hub` → Artifact Hub, `helm search repo` → repos locales añadidos) y cómo leerlo (`helm show chart` → metadata; `helm show values` → la **API** del chart; `helm show readme` → documentación del autor).

Este ejemplo es la práctica mínima **antes** de pensar en `helm install`. Si no sabes leer un chart ajeno, no deberías instalarlo.

## Contexto

En `theory/lesson.md` §2 vimos los conceptos (chart, repository, values). Aquí los vemos **operados** vía CLI contra charts reales del ecosistema (ingress-nginx, cert-manager). Todo lo que hacemos aquí es **lectura**: ningún recurso toca ningún cluster.

## Objetivo

Al terminar podrás:

- Buscar un chart por palabra clave en Artifact Hub (`helm search hub`).
- Añadir un repo HTTP y buscar localmente (`helm search repo`).
- Imprimir la metadata de un chart (`helm show chart`) e identificar `version` vs `appVersion`.
- Imprimir el `values.yaml` por defecto (`helm show values`) y reconocer que **es la API**.
- Imprimir el README del autor (`helm show readme`) y usarlo como primera fuente de verdad.

## Prerrequisitos

- Binario `helm` instalado (si no lo tienes, ver actividad 01).
- Conexión a Internet (Artifact Hub).

**Costos**: ninguno.

## Diagrama — qué consulta cada subcomando

```
┌───────────────────────────────────────────────────────────────┐
│                    Artifact Hub (artifacthub.io)              │
│    índice público de repos de charts (y otros artefactos)     │
└───────────────────────────────────────────────────────────────┘
                            ▲
                            │  helm search hub <keyword>
                            │  (red — no requiere repos locales)
                            │
                    ┌───────┴────────┐
                    │ cliente 'helm' │
                    └───────┬────────┘
                            │
                            │  helm search repo <keyword>
                            │  (consulta ~/.config/helm/repositories.yaml)
                            │  (solo repos añadidos localmente)
                            ▼
┌───────────────────────────────────────────────────────────────┐
│  Repo HTTP ingress-nginx                                      │
│    https://kubernetes.github.io/ingress-nginx/index.yaml      │
│    + archivos .tgz de cada versión del chart                  │
└───────────────────────────────────────────────────────────────┘
```

## Recorrido comentado

### 1. Verifica el entorno

```bash
helm version
helm env
```

`helm version` imprime la versión del cliente (p. ej. `v3.14.0`). `helm env` imprime variables como `HELM_CACHE_HOME`, `HELM_CONFIG_HOME`, `HELM_DATA_HOME`, `HELM_REPOSITORY_CONFIG`. **Memoriza:** `HELM_REPOSITORY_CONFIG` apunta al archivo (`repositories.yaml`) donde Helm guarda los repos que has añadido localmente.

### 2. Busca en Artifact Hub (red, sin repos locales)

```bash
helm search hub ingress-nginx --max-col-width 60
```

Salida parecida a:

```
URL                                                           CHART VERSION APP VERSION DESCRIPTION
https://artifacthub.io/packages/helm/ingress-nginx/ingress... 4.10.0        1.10.0      Ingress controller for Kubernetes using NGINX ...
https://artifacthub.io/packages/helm/bitnami/nginx-ingress... 10.1.0        1.10.0      NGINX Ingress Controller is an Ingress controller ...
...
```

Observa: cada fila es un chart distinto (del mismo o diferentes repos) con su **CHART VERSION** y **APP VERSION**. Son dos cosas distintas (ver lección §2.1).

### 3. Añade el repo oficial de ingress-nginx y refresca el índice

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Esto escribe en `HELM_REPOSITORY_CONFIG` (`repositories.yaml`) la entrada del repo y descarga su `index.yaml` al cache local (`HELM_CACHE_HOME`).

### 4. Busca en los repos locales (ya con uno añadido)

```bash
helm search repo ingress-nginx --versions | head -5
```

`--versions` lista todas las versiones disponibles (no solo la última).

### 5. Lee la metadata del chart

```bash
helm show chart ingress-nginx/ingress-nginx
```

Salida (recortada):

```yaml
apiVersion: v2
appVersion: 1.10.0
description: Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer
home: https://github.com/kubernetes/ingress-nginx
icon: https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Nginx_logo.svg/500px-Nginx_logo.svg.png
keywords:
  - ingress
  - nginx
kubeVersion: '>=1.21.0-0'
maintainers:
  - name: rikatz
  - name: strongjz
  - name: tao12345666333
name: ingress-nginx
sources:
  - https://github.com/kubernetes/ingress-nginx
type: application
version: 4.10.0
```

Lee: `version: 4.10.0` es la versión del **chart**; `appVersion: 1.10.0` es la versión del **binario nginx** empaquetado. **No son lo mismo.**

### 6. Lee los `values.yaml` por defecto — **la API**

```bash
helm show values ingress-nginx/ingress-nginx > /tmp/ingress-values.yaml
wc -l /tmp/ingress-values.yaml
```

Son cientos o miles de líneas. **Esto es la API del chart.** Cada top-level key (`controller`, `defaultBackend`, `rbac`, `tcp`, `udp`, …) es un sub-objeto configurable. Hazte estas preguntas al leerlo:

- ¿Cómo le pido N réplicas? → busca `controller.replicaCount` o `controller.autoscaling`.
- ¿Cómo configuro el `type` del Service? → `controller.service.type`.
- ¿Cómo habilito métricas de Prometheus? → `controller.metrics.enabled`.
- ¿Cómo activo TLS por default? → busca entradas con `tls`.

Si no puedes responder esas preguntas con el `values.yaml`, probablemente el chart está mal documentado — y es señal para dudar antes de usarlo.

### 7. Lee el README que publicó el autor del chart

```bash
helm show readme ingress-nginx/ingress-nginx | head -40
```

El README es prosa — explica el chart, da ejemplos, indica compatibilidad de versiones de Kubernetes, advertencias. **Siempre léelo antes del primer `install`.**

### 8. Variante: ver todo en un comando

```bash
helm show all ingress-nginx/ingress-nginx | less
```

`show all` concatena `chart` + `values` + `readme`. Útil para una ojeada rápida.

## Observaciones

1. **Ningún comando aquí tocó un cluster.** Son todas operaciones de lectura contra Artifact Hub, repos HTTP, o archivos locales.
2. **Dos niveles de búsqueda.** `helm search hub` (red, Artifact Hub, sin añadir nada local). `helm search repo` (solo los repos que *tú* añadiste con `helm repo add`). Confundirlos frustra.
3. **`values.yaml` es la API.** Antes de `helm install`, haz `helm show values` y entiéndelo. Si no, instalas a ciegas.
4. **`version` vs `appVersion`.** Dos versiones independientes. Pínealas ambas conscientemente en producción (`--version` para el chart; la del software la elige el chart).

## Próximo paso

→ `examples/02-tiller-vs-helm3-notes/` — por qué Helm 3 es client-side y qué cambió respecto a Helm 2.
