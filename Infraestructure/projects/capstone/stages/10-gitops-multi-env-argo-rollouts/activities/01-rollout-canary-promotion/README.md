# Actividad `cap-10-01` — Promoción canary multi-ambiente

**Tipo:** `guided-lab` · **Nivel:** `advanced` · **Tiempo:** ~120 min.

## Contexto

Al cerrar la etapa 9 tienes un `Application` manual contra un `Deployment` en
un solo namespace. Aquí lo escalas a tres ambientes (`dev`, `staging`, `prod`)
vía `ApplicationSet` y sustituyes el `Deployment` por un `Rollout` canary
analizado por Prometheus.

## Objetivos

Ver `activity.yaml`.

## Pasos

1. **Instalar Argo Rollouts y el Image Updater** (ver `README.md` de la etapa,
   sección 4.1).
2. **Copiar los manifiestos de la etapa a tu repo de manifiestos**:
   - `argocd/applicationsets/fastapi-app.yaml`
   - `argocd/analysis-templates/success-rate.yaml`
   - `rollouts/fastapi-rollout.yaml`
   - `argocd/image-updater-config.yaml`
3. **Aplicar y confirmar sync.** `argocd app list` debe mostrar las tres
   `Applications` en `Synced/Healthy`.
4. **Promover una versión.** Bumpa manualmente la imagen en
   `envs/dev/values.yaml` de `1.0.0` → `1.1.0`, commit + push. Observa con
   `kubectl argo rollouts get rollout fastapi-api -n dev --watch` cómo pasa
   por los 4 `setWeight`.
5. **Forzar un `AnalysisRun` fallido.** Degrada manualmente la métrica (por
   ejemplo lanzando errores 500 contra el `canary Service` con
   `hey -n 1000 -c 10 http://.../error`). Confirma que el `Rollout` entra en
   `Degraded` y hace `abort`.
6. **Validar.** Ejecuta `bash tests/validate.sh` desde la raíz del stage.

## Criterios de aceptación

- `validate.sh` imprime `RESULT: N/N checks OK` y exit code `0`.
- `argocd app sync` es idempotente (segunda corrida: `Synced` sin cambios).
- Un `git revert` del bump de imagen restaura la versión anterior.

## Entregables

- Screenshot o salida de `kubectl argo rollouts get` con el canary completo
  en `dev`.
- Screenshot de un canary abortado por `AnalysisRun` en `staging` o `prod`.
- Un PR (o commit) de promoción visible en el repo de manifiestos.

## Hints progresivos (si te atascas)

1. ¿La `AnalysisTemplate` está en el **mismo namespace** que el `Rollout`?
2. ¿El `argocd-image-updater` tiene acceso al registry? `kubectl logs -n argocd deploy/argocd-image-updater`.
3. ¿El canary se queda en `Paused`? `kubectl argo rollouts promote fastapi-api -n <env>`.
