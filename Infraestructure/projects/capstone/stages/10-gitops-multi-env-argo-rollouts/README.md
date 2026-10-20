# Etapa 10 — GitOps multi-ambiente + Argo Rollouts

> Fase 5 · Capstone · Dominio D8
> Prerequisito: etapa 9 (Helm chart propio + Argo CD single-env) cerrada.

Esta etapa escala el flujo GitOps del capstone de **un solo ambiente** a **tres**
(`dev`, `staging`, `prod`) usando un **ApplicationSet** de Argo CD, y reemplaza
el `Deployment` por un **Argo Rollouts canary** con pasos `5 → 25 → 50 → 100 %`,
pausa manual entre pasos clave y análisis automático de **success rate** desde
Prometheus. La promoción de versiones entre ambientes la decide **Argo CD Image
Updater** sobre un `write-back: git` para que todo quede auditable en el repo
de manifiestos.

---

## 1. Resumen de la etapa

**Objetivo (2–3 líneas).** Pasar de un único `Application` manual a un
`ApplicationSet` que genera tres `Application` (uno por ambiente), con una
estrategia de release **canary analizada** por métricas y una ruta de
promoción **declarativa** mediante actualizaciones de imagen escritas de vuelta
a Git.

**Delta respecto a la etapa 9.**

| Antes (etapa 9)                            | Ahora (etapa 10)                                                       |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| Un solo `Application` apuntando a `main`.  | `ApplicationSet` con generador `list` para `dev/staging/prod`.         |
| `kind: Deployment` nativo.                 | `kind: Rollout` (Argo Rollouts) con `canary` y 4 pasos de peso.        |
| `kubectl rollout` sin análisis.            | `AnalysisTemplate` `success-rate` con PromQL + umbral `>= 0.95`.       |
| Bump de imagen manual con `helm upgrade`.  | **Argo CD Image Updater** con `write-back: git` → PR de promoción.    |
| Un solo cluster `kind`, un namespace.      | Un cluster `kind`, tres namespaces aislados por `ApplicationSet`.      |

**Fuera de scope (próxima iteración).** Multi-cluster real, blue/green,
experimentos con `AnalysisRun` adicionales (latencia p99, error-budget burn),
ESO/Vault para secretos (etapa 12), y Backstage scorecards (etapa 13).

---

## 2. Arquitectura al cierre de esta etapa

```
                              repo-de-codigo (Git)
                                      │
                                      │ CI push de imagen semver → GHCR
                                      ▼
                        ┌───────────────────────────┐
                        │  GHCR: ghcr.io/acme/api   │
                        │  tags: 1.2.3, 1.2.4, ...  │
                        └─────────────┬─────────────┘
                                      │  (scrape cada 2 min)
                                      ▼
                        ┌───────────────────────────┐
                        │  Argo CD Image Updater    │  write-back: git
                        │  en namespace argocd      │──────────────────┐
                        └─────────────┬─────────────┘                  │
                                      │                                ▼
                                      │                   repo-de-manifiestos (Git)
                                      │                   ├── envs/dev/values.yaml
                                      │                   ├── envs/staging/values.yaml
                                      │                   └── envs/prod/values.yaml
                                      ▼
                        ┌───────────────────────────┐
                        │  Argo CD ApplicationSet   │  genera 3 Applications
                        │  fastapi-app              │
                        └─────┬──────────┬──────────┘
                              │          │
            ┌─────────────────┘          ├──────────────────┐
            ▼                            ▼                  ▼
     ┌────────────┐              ┌────────────┐      ┌────────────┐
     │  ns: dev   │              │ns: staging │      │  ns: prod  │
     │  Rollout   │              │  Rollout   │      │  Rollout   │
     │  canary    │  AnalysisRun │  canary    │      │  canary    │
     │  5/25/50/100 ───(Prom)──► │  + pausa   │      │  + pausa   │
     └────────────┘              └────────────┘      └────────────┘
```

**Entradas / salidas.**

- **Entrada:** imágenes semver publicadas por el pipeline de la etapa 5
  (`ghcr.io/<org>/fastapi-api:X.Y.Z`), chart Helm de la etapa 9.
- **Salida:** tres `Application` sincronizados, tres `Rollout` en estado
  `Healthy`, Prometheus con métricas `http_requests_total` por versión.

**Resource list (dentro del cluster `kind`).**

- `Namespace`: `argocd`, `argo-rollouts`, `dev`, `staging`, `prod`, `monitoring`.
- `ApplicationSet` + 3 `Application` generados.
- `AnalysisTemplate` `success-rate` (por ambiente).
- `Rollout` `fastapi-api` (por ambiente), `Service` activo + preview.
- `ConfigMap` `argocd-image-updater-config` + `Secret` dummy `ghcr-creds`.

---

## 3. Prerrequisitos verificados

Antes de arrancar, confirma los outputs de las etapas 1–9:

- [ ] Imagen `ghcr.io/<org>/fastapi-api:1.0.0` publicada y firmada (etapa 5).
- [ ] Chart Helm `charts/fastapi-api/` con `values.yaml` por ambiente (etapa 9).
- [ ] Cluster `kind` con Argo CD instalado y un `Application` ya en `Synced`
  (etapa 9).
- [ ] `kubectl`, `helm`, `argocd` CLI, `kubectl-argo-rollouts` plugin instalados.
- [ ] Prometheus corriendo en `monitoring` (puede ser el stack mínimo de la
  etapa 9; la observabilidad completa es etapa 11, pero necesitamos un endpoint
  `prometheus:9090` dentro del cluster para que la `AnalysisTemplate` consulte).

Si falta cualquiera: cierra primero esa etapa; no saltes.

---

## 4. Implementación guiada

### 4.1 Instalar Argo Rollouts y el Image Updater

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

### 4.2 Materializar los manifiestos de esta etapa

Copia este stage a tu repo de manifiestos y commitea:

```
argocd/applicationsets/fastapi-app.yaml   # un ApplicationSet, 3 envs
argocd/analysis-templates/success-rate.yaml
argocd/image-updater-config.yaml          # anotaciones + credenciales dummy
rollouts/fastapi-rollout.yaml             # canary 5/25/50/100 + pausa + analysis
```

Luego aplica:

```bash
kubectl apply -f argocd/applicationsets/fastapi-app.yaml
kubectl apply -f argocd/analysis-templates/success-rate.yaml   # por ambiente
kubectl apply -f argocd/image-updater-config.yaml
```

### 4.3 Decisiones materiales (por qué, no sólo qué)

- **`ApplicationSet` + generador `list` vs. `git-directory`.** Con `list`
  dejamos el "qué ambientes existen" en un sólo archivo versionado; con
  `git-directory` tendríamos que crear/eliminar carpetas para dar de alta
  ambientes. En etapas tempranas `list` es más predecible y la diff es obvia
  en un PR.
- **Canary 5/25/50/100 con pausa indefinida después del 25 %.** El 5 %
  valida que no haya un `CrashLoopBackOff` o un error 5xx inmediato; el 25 %
  es donde el `AnalysisRun` corre contra Prometheus (ya hay tráfico
  suficiente para una tasa estadísticamente útil); la pausa indefinida tras
  el 25 % es el gate humano para `prod` (en `dev` se auto-promueve con
  `setWeight: 25` sin `pause` indefinida — ver `values.yaml` por env).
- **Umbral `success-rate >= 0.95`.** Deliberadamente laxo para un capstone
  educativo con tráfico sintético; en producción real se calcula contra el
  SLO del servicio (etapa 11 lo refinará).
- **Image Updater con `write-back: git` en lugar de `argocd`.** Queremos
  que la promoción deje huella en Git (auditoría, revert con `git revert`),
  no que mute el `Application` en caliente.
- **Un cluster, tres namespaces vs. tres clusters.** Multi-cluster real
  (ArgoCD `cluster` secrets) es educativamente valioso pero caro para un
  capstone local; se pospone a etapa 11 cuando ya hay observabilidad para
  compararlos.

### 4.4 Verificación end-to-end

```bash
argocd app list
# Esperado: fastapi-dev, fastapi-staging, fastapi-prod todos Synced/Healthy.

kubectl argo rollouts get rollout fastapi-api -n dev --watch
# Esperado: 4 pasos, análisis OK, Healthy en < 5 min.
```

Para disparar una promoción, bumpa la imagen manualmente en el repo:

```bash
# simula lo que haría el Image Updater
sed -i '' 's/tag: 1.0.0/tag: 1.1.0/' envs/dev/values.yaml
git commit -am "chore(dev): promote fastapi-api to 1.1.0"
git push
```

Argo CD detecta el cambio en < 3 min y Argo Rollouts arranca el canary.

---

## 5. Actividades del estudiante

Esta etapa incluye una actividad `guided-lab`:

- **`cap-10-01-rollout-canary-promotion`** — Promover `1.0.0 → 1.1.0` en
  `dev`, observar el canary completar, forzar un fallo del análisis
  degradando una métrica, confirmar que el `Rollout` ejecuta `abort` y queda
  en `Degraded` sin tocar los `ReplicaSet` estables.

Ver `activities/01-rollout-canary-promotion/README.md`.

---

## 6. Entregables

Al terminar la etapa, el estudiante debe tener versionado y commiteado:

- `argocd/applicationsets/fastapi-app.yaml` desplegado y generando 3 apps.
- `argocd/analysis-templates/success-rate.yaml` en cada namespace.
- `rollouts/fastapi-rollout.yaml` referenciado por el chart Helm.
- `argocd/image-updater-config.yaml` con anotaciones por `Application`.
- Un PR (o commit) de promoción `1.0.0 → 1.1.0` visible en el historial.
- Capturas o `argo rollouts get` del canary completo y de un canary abortado.

---

## 7. Pruebas y criterios de aceptación

Verificables automáticamente por `activities/01-*/tests/validate.sh`:

- `yaml.safe_load` sobre los cuatro manifiestos pasa sin excepción.
- `ApplicationSet.spec.generators[0].list.elements` lista `dev`, `staging`,
  `prod` (orden irrelevante).
- `Rollout.spec.strategy.canary.steps` contiene los cuatro `setWeight`
  `5, 25, 50, 100` en orden y al menos un `pause{}` (indefinida).
- `AnalysisTemplate.spec.metrics[0].successCondition` referencia `>= 0.95`.
- `argocd-image-updater-config` tiene `argocd.argoproj.io/image-list` como
  anotación o referencia dentro de un `ConfigMap`.

Criterios cualitativos:

- [ ] Ningún secreto real en Git (credenciales de GHCR son placeholders).
- [ ] `argocd app sync` idempotente: segunda corrida no muestra `OutOfSync`.
- [ ] Rollback por `git revert` del bump de imagen restaura el estado anterior.

---

## 8. Costos y limpieza

**Costo estimado.** `$0 / mes`. Todo corre en `kind` local.

**Limpieza completa.**

```bash
kubectl delete applicationset fastapi-app -n argocd
kubectl delete namespace dev staging prod argo-rollouts
kubectl delete -n argocd -f \
  https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
# Si Argo CD y el cluster kind se van a reusar en etapa 11, dejarlos arriba.
# Si no:
kind delete cluster --name capstone
```

Guard-rails: no hay recursos cloud; el único riesgo es dejar `kind`
consumiendo RAM. `docker stats` para auditar.

---

## 9. Riesgos y mitigaciones

| # | Riesgo                                                        | Mitigación                                                                                      |
| - | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1 | Prometheus aún no está instalado y el `AnalysisRun` falla.   | La `AnalysisTemplate` incluye `failureLimit: 2`; el estudiante puede stubear la métrica con un `provider: job` que devuelve `1`. |
| 2 | Image Updater no tiene permisos de push al repo.             | Usar un PAT dummy en un `Secret` llamado `git-creds` y documentar que en etapa 12 lo moveremos a ESO. |
| 3 | El canary queda colgado en `Paused` indefinidamente en prod. | Documentar el comando de promoción `kubectl argo rollouts promote fastapi-api -n prod` y añadirlo al runbook. |

**Hints progresivos (si el estudiante se atasca).**

1. "¿Qué devuelve `argocd app get fastapi-dev`? ¿`Synced` o `OutOfSync`?"
2. "¿La `AnalysisTemplate` está en el mismo namespace que el `Rollout`?"
3. (Sólo si lo pide explícitamente) Mostrar un ejemplo de `AnalysisRun` resuelto.

---

## 10. Puente con la siguiente etapa

**Qué habilita.** Tener tres ambientes GitOps-ificados y una estrategia de
release analizada por métricas es el **requisito previo** para la etapa 11,
donde las métricas pasan de "sintéticas para el analysis" a un stack real
(Prometheus Operator + Grafana + Loki + OTel + SLOs). La etapa 11 reutilizará
la `AnalysisTemplate` cambiando el `provider.prometheus.address` por el
`Service` del operator.

**Qué dejar corriendo.** El cluster `kind`, Argo CD, Argo Rollouts, y los
tres `Application`. Apagar los `Rollout` baja el valor educativo porque la
etapa 11 pide ver métricas vivas.

**Cliffhanger.** *"El `AnalysisRun` compara success-rate contra `>= 0.95`.
¿Qué pasa si tu SLO real es `99.9 %` y el tráfico sintético no basta para
detectar la diferencia en 5 minutos? La etapa 11 responde con error-budget
burn-rate alerts."*
