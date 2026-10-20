# Recursos — argo-07

## Documentación oficial Argo CD

- **ApplicationSet overview** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/>
- **Generators (índice)** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/>
  - **List** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-List/>
  - **Cluster** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/>
  - **Git** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/>
  - **Matrix** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Matrix/>
  - **Merge** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Merge/>
  - **SCM Provider** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-SCM-Provider/>
  - **Pull Request** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/>
- **Template** y variables — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Template/>
- **Go template engine (`goTemplate: true`)** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/>
- **Progressive syncs** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/>
- **Controller flags y configuración** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Controlling-Resource-Modification/>

## Lecturas complementarias

- **Codefresh blog — ApplicationSet patterns** — <https://codefresh.io/blog/>
- **Akuity blog** — <https://akuity.io/blog/>
- **"App-of-apps" vs ApplicationSet (post oficial Argo CD)** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/>

## Herramientas

- **`argocd` CLI** — <https://argo-cd.readthedocs.io/en/stable/cli_installation/>
- **`kind`** — <https://kind.sigs.k8s.io/>
- **`yq`** — <https://mikefarah.gitbook.io/yq/>

## Especificación del CRD

- **`argoproj.io/v1alpha1 ApplicationSet` schema** — ver `kubectl explain applicationset.spec` sobre un cluster con el CRD, o buscar `applicationset-crd.yaml` en el repo `argoproj/argo-cd`.

## Nota de verificación

Última verificación de enlaces: pendiente de Fase 4. Todos los enlaces son dominios oficiales (`argo-cd.readthedocs.io`, `codefresh.io`, `akuity.io`, `kind.sigs.k8s.io`); verificar fecha y disponibilidad al desarrollar el curso en producción.
