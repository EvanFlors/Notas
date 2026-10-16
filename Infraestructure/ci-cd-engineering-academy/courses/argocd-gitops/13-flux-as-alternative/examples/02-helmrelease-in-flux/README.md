# Example 02 — `HelmRelease` en Flux

Despliega `podinfo` como `HelmRelease` real (no `helm template`) y observa la historia Helm.

## Qué demuestra

- `HelmRepository` apuntando a un chart repo HTTPS.
- `HelmRelease` ejecutando `helm install/upgrade` real.
- `helm history -n podinfo podinfo` muestra revisiones reales (en Argo CD estaría vacío).
- Rollback declarativo (`spec.rollback.cleanupOnFail`).

## Requisitos

- `kind`, `kubectl`, `helm`, `flux`

Si falta algo, SKIP limpio.

## Ejecutar

```bash
bash run.sh
```

## Limpieza

```bash
bash cleanup.sh
```

## Observación clave

Después del apply, `helm -n podinfo list` muestra el release. Esto **no sucede** con Argo CD usando `source.helm` — Argo CD renderiza y aplica, pero no deja Helm metadata porque no corre `helm install`.
