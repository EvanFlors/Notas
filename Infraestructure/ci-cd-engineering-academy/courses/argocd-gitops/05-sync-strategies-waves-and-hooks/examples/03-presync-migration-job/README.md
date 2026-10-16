# Example 03 — Hook PreSync para migración

`Job` con anotación `argocd.argoproj.io/hook: PreSync` que corre **antes** de que el `Deployment` del app sincronice. Si el `Job` falla, el sync aborta y el `Deployment` no se toca.

## Qué demuestra

- Hook `PreSync` con delete-policy `BeforeHookCreation,HookSucceeded`.
- `backoffLimit: 0` para que el retry lo maneje Argo CD (sync-level), no el `Job`.
- `restartPolicy: Never` (requerido para Job hooks).
- Convivencia con un `Deployment` normal que sigue el flujo canónico.

## Archivos

- `application.yaml` — Application que apunta a `app/`.
- `app/00-migration-job.yaml` — el hook.
- `app/10-deployment.yaml` — la app que depende de la migración.

## Probar

```sh
kubectl apply -f application.yaml
kubectl -n argocd get application presync-demo -w
kubectl -n presync-demo get jobs,pods -w
```

Observarás: el `Job` `migrate` corre primero, completa, luego arranca el `Deployment`. Con la delete-policy `HookSucceeded`, el `Job` **desaparece** del cluster tras éxito.

## Simular fallo

Editar `app/00-migration-job.yaml` para cambiar el `command` del container a `["sh", "-c", "exit 1"]`, hacer commit y push. En el próximo sync:

- Argo CD aplica el Job, el Job falla.
- El sync aborta; `Deployment` no se toca.
- El `Job` fallido queda in situ (no está `HookFailed` en la policy) → `kubectl logs job/migrate -n presync-demo` para depurar.

## Trampas

- `backoffLimit > 0` confunde a Argo CD. Dejar siempre en `0` para hooks.
- Hooks de Helm (`"helm.sh/hook"`) **no funcionan** bajo Argo CD. Si vienes de Helm, migrar a `"argocd.argoproj.io/hook"`.
- Si el `Job` toma más que el `--sync-timeout` (default 10 min), el sync falla por timeout aunque la migración siga corriendo. Ajustar vía `argocd app sync --timeout 30m` o via settings de Argo CD.
