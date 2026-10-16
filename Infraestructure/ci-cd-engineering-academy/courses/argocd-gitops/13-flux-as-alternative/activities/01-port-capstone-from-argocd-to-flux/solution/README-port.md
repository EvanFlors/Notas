# Solución de referencia — porting del capstone (podinfo como stand-in)

> Esta es **una** solución válida. Es solo referencia; se espera que el estudiante produzca la suya con decisiones propias.

## Decisión

- **Chart Helm** `podinfo` como stand-in del capstone (misma forma: chart Helm con values por entorno).
- Fuente: `HelmRepository` apuntando a `https://stefanprodan.github.io/podinfo`.
- Despliegue: `HelmRelease` en el namespace `capstone`.
- Prune: `true` para equivalencia con el `syncPolicy.automated.prune` del Argo CD original.
- Intervalo: 5m (equilibrio entre latencia de reconciliación y carga).
- Sin `dependsOn` porque es un single-release.

## Por qué `HelmRelease` y no `Kustomization`

El capstone original en `argo-04` se definió con `source.helm` → el equivalente natural es `HelmRelease`. Beneficio adicional: `helm history -n capstone capstone` muestra revisiones reales — útil para debugging.

## Reversibilidad a Argo CD

Para volver: suspender el `HelmRelease` (`flux suspend helmrelease capstone -n capstone`), aplicar la `Application` original de Argo CD con los mismos `values`, verificar `argocd app sync capstone`, luego `kubectl delete helmrelease capstone -n capstone`. Los manifests desplegados en el cluster son idénticos byte-a-byte después del handover (ambos consumen el mismo chart + values).

## Trade-offs observados

- Flux es más explícito: dos CRs (`HelmRepository` + `HelmRelease`) en vez de uno (`Application`). A cambio, el acoplamiento es visible — el `sourceRef` apunta explícitamente.
- `helm install` real: hooks del chart funcionarían (si los hubiera). En Argo CD habría que reescribirlos como hooks de Argo.
- Sin UI con write — si estaba acostumbrado a `argocd app sync` desde la UI, aquí es `flux reconcile helmrelease capstone -n capstone`.
