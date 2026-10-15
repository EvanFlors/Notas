# Actividad 02 — ARC mínimo en kind + ADR

## 1. Identificación

- **ID:** `gha-10-02-arc-minimal-install`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-10-self-hosted-runners-and-arc`
- **Dificultad:** advanced
- **Duración estimada:** 90–150 min
- **Tipo:** mini-project (independent)

## 2. Contexto

Mini-proyecto. Dos entregables:

- **Infra**: un cluster `kind` con el **operator** de ARC instalado y un **scale set** con credenciales dummy. Esto demuestra que entiendes la pieza y sabes operarla, aun sin conectar a GitHub real.
- **ADR**: un documento de arquitectura comparando `GitHub-hosted` vs `larger runners` vs `self-hosted VMs` vs `ARC` para un escenario de empresa dado, con decisión justificada.

Se evalúa automáticamente:

- Modo **`infra`** (default si tienes `kind`+`kubectl`+`helm`): valida el cluster y los CRDs.
- Modo **`docs-only`** (fallback automático si falta alguna herramienta): valida solo el ADR.

Si la toolchain está, se evalúan **ambos**.

## 3. Objetivos

Al terminar:

- Operas `kind create cluster` con un config simple.
- Instalas el chart `gha-runner-scale-set-controller` y verificas las 4 CRDs esperadas.
- Instalas un scale set `gha-runner-scale-set` con PAT dummy y verificas que:
  - el `AutoscalingRunnerSet` CR fue creado,
  - el pod listener existe (puede estar en `CrashLoopBackOff` por auth; es la señal esperada).
- Escribes un ADR siguiendo la plantilla, con una decisión defendible.

## 4. Prerrequisitos

- `gha-10-01` completado.
- `docker` corriendo.
- Idealmente: `kind` ≥ 0.20, `kubectl` ≥ 1.28, `helm` ≥ 3.12.
- Si falta cualquiera: el validador salta a `docs-only` y pide solo el ADR, pero debes documentar en el ADR cuál es tu plan para instalar la toolchain.

**Costos:** $0 (todo local, imágenes públicas).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/arc-mini
cd /tmp/arc-mini
ls
# docs/              <- aquí va el ADR
# manifests/         <- values.yaml y kind-config.yaml ejemplos
# bin/               <- scripts helper (opcionales)
```

### 5.2 Entregable A — Infra (si tienes kind+kubectl+helm)

Produce el cluster y los releases. Un camino directo (puedes usar `bin/apply-infra.sh` como atajo o hacerlo paso a paso):

**Paso 1 — Cluster**:

```bash
kind create cluster --name arc-mini --config /tmp/arc-mini/manifests/kind-config.yaml
kubectl cluster-info --context kind-arc-mini
```

**Paso 2 — Namespaces**:

```bash
kubectl create namespace arc-systems
kubectl create namespace arc-runners
```

**Paso 3 — Operator (chart oficial)**:

```bash
helm install arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.9.3
```

**Paso 4 — Secret dummy** (no conectará, está bien):

```bash
kubectl create secret generic github-dummy \
  --namespace arc-runners \
  --from-literal=github_token='ghp_dummyDUMMYdummyDUMMYdummyDUMMYdummy0'
```

**Paso 5 — Scale set**:

```bash
helm install my-runners \
  --namespace arc-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.9.3 \
  -f /tmp/arc-mini/manifests/values.yaml
```

(`manifests/values.yaml` ya trae el `githubConfigUrl` ficticio y `githubConfigSecret: github-dummy`.)

**Paso 6 — Verifica**:

```bash
kubectl get crd | grep actions.github.com
# ...autoscalingrunnersets.actions.github.com
# ...autoscalinglisteners.actions.github.com
# ...ephemeralrunners.actions.github.com
# ...ephemeralrunnersets.actions.github.com

kubectl get autoscalingrunnerset -n arc-runners
# NAME         ...

kubectl get pods -n arc-systems
# arc-gha-rs-controller-xxxx   Running

kubectl get pods -n arc-runners
# my-runners-xxxx-listener     CrashLoopBackOff   <-- OK, el PAT es dummy
```

### 5.3 Entregable B — ADR

Edita **`/tmp/arc-mini/docs/ADR-001-runner-choice.md`** respondiendo al escenario del starter.

El starter deja un stub con la plantilla (sección 8 de la lección). Debes:

- Describir el **contexto** (lo da el enunciado del starter: visibilidad, volumen, VPC, etc.).
- Listar las **4 opciones**.
- Dar una **decisión** (una línea).
- Enumerar **al menos 3 consecuencias** (operación, coste, seguridad).

El validador exige que el archivo tenga, al menos:

- Secciones `## Contexto`, `## Opciones evaluadas`, `## Decisión`, `## Consecuencias`.
- Que `## Opciones evaluadas` mencione los 4: `hosted`, `larger`, `self-hosted`, `ARC`.
- Longitud mínima 500 caracteres (no se trata de ser verboso; se trata de que haya pensamiento).

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/arc-mini
```

El validador:

- Detecta si `kind`, `kubectl`, `helm`, `docker` están disponibles.
- Si **sí**: valida infra + ADR.
- Si **falta alguno**: imprime `SKIP infra ...` con qué instalar y valida solo el ADR.

Resultado esperado: `OK: actividad completada correctamente.` en ambos modos.

## 6. Resultado esperado

Modo `infra+adr`:

- Cluster `kind-arc-mini` accesible por `kubectl`.
- CRDs de `actions.github.com` instaladas (≥ 2 de las 4 principales).
- Namespace `arc-runners` con un `AutoscalingRunnerSet` llamado `my-runners`.
- Pod `arc-gha-rs-controller-*` en `Running`.
- ADR válido.

Modo `docs-only`:

- ADR válido con las 4 secciones y las 4 opciones mencionadas.

## 7. Criterios de aceptación

- [ ] (si aplica) Cluster `kind-arc-mini` existe y responde.
- [ ] (si aplica) Operator `arc-gha-rs-controller` Running.
- [ ] (si aplica) ≥ 2 CRDs `actions.github.com` presentes.
- [ ] (si aplica) `AutoscalingRunnerSet` `my-runners` existe en `arc-runners`.
- [ ] ADR presente, con 4 secciones y mención de las 4 opciones.
- [ ] ADR ≥ 500 caracteres.

## 8. Validación

```bash
bash tests/validate.sh /tmp/arc-mini
```

Modos:

- Automático: elige `infra+adr` si toolchain está, `docs-only` si no.
- Forzado: `MODE=docs-only bash tests/validate.sh /tmp/arc-mini` evalúa solo el ADR (útil en CI).
- Forzado: `MODE=infra bash tests/validate.sh /tmp/arc-mini` evalúa solo infra.

## 9. Preguntas de reflexión

1. ¿Por qué dos charts distintos (operator + scale set) y no uno solo?
2. ¿Qué significa que el pod listener esté en `CrashLoopBackOff` con un PAT dummy, y por qué eso **confirma** que todo está bien instalado?
3. En tu ADR, ¿cuál fue el **criterio decisivo**? ¿Qué habría tenido que cambiar para que eligieras diferente?
4. Si fuese un repo público, ¿puedes defender ARC igualmente? ¿Qué 3 controles adicionales exigirías?
5. Con `minRunners: 0`, ¿cuál es la latencia que esperas desde que se encola un job hasta que el primer step corre? ¿Qué harías si duele?
6. ¿Dónde dejarías los secretos de la GitHub App que ARC usa en producción? (Pista: no en el repo).

## 10. Extensiones (opcional)

- **E1** — Instala Prometheus en el cluster y expone las métricas del operator (`--set metrics.serviceMonitor.enable=true`).
- **E2** — Añade `minRunners: 1` y observa que un pod runner "warm" aparece sin ningún job encolado.
- **E3** — Cambia el PAT por credenciales de GitHub App (`--set githubConfigSecret.github_app_id=... github_app_installation_id=... github_app_private_key=...`).
- **E4** — Haz dos scale sets en el mismo cluster (`cpu-runners`, `gpu-runners`) y describe cómo los diferencia el workflow.

## 11. Limpieza

```bash
# Infra
helm uninstall my-runners -n arc-runners 2>/dev/null || true
helm uninstall arc        -n arc-systems 2>/dev/null || true
kubectl delete ns arc-runners arc-systems --ignore-not-found 2>/dev/null || true
kind delete cluster --name arc-mini 2>/dev/null || true

# Scratch
rm -rf /tmp/arc-mini
```
