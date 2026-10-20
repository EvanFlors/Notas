# Recursos — argo-04

## Documentación oficial

- Argo CD — **Tool support (sources)**: <https://argo-cd.readthedocs.io/en/stable/user-guide/application_sources/>
- Argo CD — **Helm**: <https://argo-cd.readthedocs.io/en/stable/user-guide/helm/>
- Argo CD — **Kustomize**: <https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/>
- Argo CD — **Jsonnet**: <https://argo-cd.readthedocs.io/en/stable/user-guide/jsonnet/>
- Argo CD — **Multi-source Applications**: <https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/>
- Argo CD — **Config Management Plugins (sidecar model)**: <https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/>
- Argo CD — **Resource hooks**: <https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/>
- Argo CD — **Sync waves**: <https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/>

## Documentación relacionada

- Helm — **Hooks**: <https://helm.sh/docs/topics/charts_hooks/>
- Kustomize — **Reference**: <https://kubectl.docs.kubernetes.io/references/kustomize/>
- Jsonnet — <https://jsonnet.org/>
- kind — <https://kind.sigs.k8s.io/>

## Charts usados en los ejemplos

- `podinfo` chart (stefanprodan): <https://github.com/stefanprodan/podinfo>
- `bitnami/nginx` chart: <https://github.com/bitnami/charts/tree/main/bitnami/nginx>
- `bitnami/postgresql` chart: <https://github.com/bitnami/charts/tree/main/bitnami/postgresql>

## Lecturas recomendadas

- Codefresh — *Argo CD + Helm best practices* (blog, actualizado periódicamente).
- Akuity — *Multi-source Applications in Argo CD* (artículo de GA).
- CNCF — *OpenGitOps principles*: <https://opengitops.dev/>

## Para profundizar

- `argocd-cm` ConfigMap y `kustomize.buildOptions`: habilita `--enable-helm` cuando combinas Helm desde Kustomize vía `helmCharts`.
- Diferencias entre `ServerSideApply=true` y Client-Side Apply para charts que generan muchos campos defaulteados.
- Interacción entre `ignoreDifferences` y charts que generan nuevas revisiones de ConfigMap/Secret por hash.
