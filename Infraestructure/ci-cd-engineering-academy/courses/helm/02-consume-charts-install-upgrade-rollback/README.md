# helm-02 — Consumir charts: install, upgrade, rollback

## Identificación

- **ID:** `helm-02-consume-charts-install-upgrade-rollback`
- **Curso:** `helm`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `helm-01-mental-model-and-setup`. Un cluster local funcional (kind o k3d). `kubectl` apuntando a él.

## Objetivo

Operar el **lifecycle de releases** con charts de terceros: añadir repositorios, instalar, actualizar y revertir con control. Al terminar deberías poder instalar software base del cluster (ingress-nginx, cert-manager, Prometheus Operator) de forma reproducible, explicar **dónde vive el estado del release**, y saber exactamente qué hace un `helm rollback`.

## Alcance

Este módulo cubre:

- Añadir y refrescar repositorios HTTP (`helm repo add/update`).
- `helm install` con sus flags cruciales: `--namespace`, `--create-namespace`, `--version`, `--values`/`-f`, `--set`.
- El patrón **`helm upgrade --install`** (idempotente, idioma estándar de CI/CD).
- `helm uninstall` y lo que deja atrás (o no).
- Inspección de releases: `helm list [--all-namespaces]`, `helm status`, `helm get values|manifest|notes|hooks`.
- **`helm history`** y `helm rollback` — qué revisión existe, a cuál volver, qué revisión *nueva* genera el rollback.
- Dónde vive el estado del release: un **Secret** (por default) en el namespace del release, uno por revisión, con el payload completo serializado y gzipeado.

Lo que **no** cubre (se verá después):

- Escribir tu propio chart → `helm-03`.
- Templating profundo (Sprig, `include`, `required`) → `helm-04`.
- Hooks y `--atomic` → `helm-07`.
- Publicar/firmar charts en OCI → `helm-08`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-install-ingress-nginx/` — primer `helm install` real, verificar recursos y leer el Secret del release.
  - `02-upgrade-with-values-file/` — `helm upgrade -f values-prod.yaml`, ver la nueva revisión y comparar valores con `helm get values`.
  - `03-rollback-walkthrough/` — provocar un upgrade problemático, inspeccionar `helm history`, y volver con `helm rollback` observando la nueva revisión que crea.
- **`activities/`**:
  - `01-install-cert-manager/` (guided-lab) — instalar cert-manager con `--version`, `--create-namespace` y CRDs; verificar con `helm status` y `kubectl`.
  - `02-rollback-after-bad-upgrade/` (independent) — instalar un chart, hacer un upgrade con un valor roto, confirmar el fallo, hacer rollback a revision 1 y verificar restauración.
- **`resources/links.md`** — documentación oficial y lecturas.

## Temas y subtemas

1. **Repositorios de charts**
   - `helm repo add <name> <url>`, `helm repo list`, `helm repo remove`.
   - `helm repo update` como "`apt update`" — refresca el `index.yaml` cacheado.
   - Dónde se cachea (`$XDG_CACHE_HOME/helm/repository/`).
2. **`helm install`**
   - Sintaxis: `helm install <RELEASE> <CHART> [flags]`.
   - `--namespace` + `--create-namespace` (sin esto, el namespace debe preexistir).
   - `--version <SemVer>` — nunca "la última" en producción.
   - Overrides de valores: `--values file.yaml` (`-f`), repetible y ordenado; `--set key=value`, `--set-string`, `--set-file`.
   - `--dry-run` + `--debug` para ver el render sin tocar el cluster.
   - `--wait` + `--timeout` para esperar readiness.
3. **El idiom `helm upgrade --install`**
   - Instala si no existe, actualiza si existe. Un solo comando para `n` ejecuciones del pipeline.
   - Por qué es la forma estándar en CI/CD (idempotencia).
   - `--reuse-values` vs `--reset-values` vs comportamiento default.
4. **`helm uninstall`**
   - Elimina los recursos renderizados y el release storage.
   - `--keep-history` para conservar el historial (útil para auditar).
   - **No** elimina PVCs ni CRDs automáticamente (gotcha típica).
5. **Inspección de releases**
   - `helm list [-A | --all-namespaces]`.
   - `helm status <release>` — resumen; `--revision N` para un snapshot pasado.
   - `helm get values <release>` — valores *efectivos* del release (user supplied por default; `--all` para incluir defaults).
   - `helm get manifest` — YAML final renderizado y aplicado.
   - `helm get notes` — el `NOTES.txt` del chart.
   - `helm get hooks` — los hooks declarados.
6. **Historial y rollback**
   - `helm history <release>` — lista todas las revisiones con estado (`deployed`, `superseded`, `failed`, `pending-upgrade`...).
   - `helm rollback <release> <REVISION>` — vuelve a la configuración de esa revisión.
   - El rollback **crea una revisión nueva** (N+1) cuyo contenido es copia del target; no "borra" la historia.
7. **Dónde vive el estado del release**
   - Backend por default: **Secret** en el namespace del release.
   - Nombre: `sh.helm.release.v1.<release>.v<revisión>`.
   - Payload: el release serializado (metadata + chart + valores + manifest renderizado), comprimido con gzip y codificado base64.
   - Alternativas: `--driver configmap` (legado), `--driver sql` (postgres, para flotas grandes).
   - Qué pasa si borras ese Secret → el release deja de existir para Helm (otra "gotcha" fundamental).

## Conceptos internos (fundamentos)

- **Un release = N revisiones = N Secrets**. Cada `install`, `upgrade` o `rollback` exitoso añade un Secret `sh.helm.release.v1.<name>.vN`. El estado "actual" es el Secret con la revisión más alta y status `deployed`. Es por esto que `helm history` puede listarlo todo con un `kubectl get secret -l owner=helm`.
- **Rollback no es "deshacer"**, es "aplicar la revisión K como si fuera un nuevo upgrade". Por eso crea la revisión N+1. Si rollback-eas de 5 a 2, la historia queda `1,2,3,4,5,6` donde 6 == contenido de 2. Esto es importante porque un `helm rollback` falla por las mismas razones que un `helm upgrade` (readiness, immutable fields en los recursos).
- **`helm upgrade --install` es el único comando correcto en un pipeline**. En CI no sabes si es la primera corrida o la quinta; `install` falla si existe, `upgrade` falla si no existe. El flag `--install` resuelve ambos casos en una sola llamada idempotente.
- **El estado del release vive *con* la aplicación**, no en una base central. Es diseño: borras el namespace → se van los recursos *y* el storage del release (no quedan huérfanos). El contra: borras por error un Secret `sh.helm.release.v1.*` y Helm "pierde" el release aunque los recursos sigan vivos (necesitarías adoptarlos con `helm install --dry-run` + mañas o reinstalar).
- **Los `--values` se mergean en orden, `--set` gana sobre `-f`**. Precedence: defaults del chart → cada `-f file.yaml` en el orden de la CLI → cada `--set` en el orden de la CLI. En diferencia con `kubectl apply`, Helm no hace server-side merging: el merge es client-side, antes de renderizar.
- **`helm uninstall` no limpia PVCs, Secrets de TLS creados por hooks ni CRDs instaladas desde `crds/`**. Esto es intencional (seguridad: evitar borrar datos reales), pero es la fuente #1 de "¿por qué no puedo reinstalar?" después de desinstalar.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué es una revisión, dónde se guarda, qué hace exactamente `helm rollback`, y por qué `helm upgrade --install` es el idiom de CI/CD. |
| Operativa | Instalar un chart con `--version`, `-f values.yaml` y `--set`; inspeccionarlo con `helm get values/manifest`; hacer un upgrade, confirmar la nueva revisión, y rollback a la anterior. |
| Arquitectónica | Justificar la elección de backend de storage (Secret vs SQL); diseñar la convención de release names y namespaces para no confundir dos instalaciones del mismo chart; decidir cuándo `--keep-history` vale la pena. |

## Entregables

- Cluster local kind con **al menos 2 charts instalados** (ingress-nginx + cert-manager) visibles en `helm list -A`.
- Evidencia (output capturado) de un **upgrade** (revisión 2) y un **rollback** (revisión 3 == copia de 1) sobre un release del laboratorio.
- Ambos `tests/validate.sh` de las actividades en verde.

## Criterios de evaluación

- **Estado del release**: dado un cluster con `helm list -A` lleno, explicar sin consultar dónde (qué namespace, qué objeto, qué nombre) está guardado el estado de cada release. Explicar qué pasa si borras `kubectl delete secret sh.helm.release.v1.cert-manager.v1`.
- **Lectura de `helm history`**: dado el output, decir cuál es la revisión "en vivo", cuántos rollbacks hubo, y si alguna revisión está en `failed` (y qué significa).
- **`upgrade --install` idempotencia**: justificar por qué nunca escribirías `helm install ... || helm upgrade ...` como atajo en un pipeline.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-install-ingress-nginx/` paso a paso.
3. Reproduce `examples/02-upgrade-with-values-file/`.
4. Haz `activities/01-install-cert-manager/`.
5. Reproduce `examples/03-rollback-walkthrough/`.
6. Haz `activities/02-rollback-after-bad-upgrade/`.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `helm-03-chart-anatomy`: dejar de ser *solo* consumidor y empezar a escribir tus propios charts.
