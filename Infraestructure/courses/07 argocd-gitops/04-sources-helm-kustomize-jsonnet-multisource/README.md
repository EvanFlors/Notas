# argo-04 — Sources: plain YAML, Helm, Kustomize, Jsonnet y Multi-source

## Identificación

- **ID:** `argo-04-sources-helm-kustomize-jsonnet-multisource`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `argo-03-application-anatomy-sources-destinations-sync`, curso **helm** (al menos niveles 1-3), familiaridad con `kustomize`.

## Objetivo

Usar Argo CD con **cada tipo de fuente soportada nativamente** (plain YAML/directory, Helm, Kustomize y, al margen, Jsonnet), **combinar múltiples sources** en una sola Application, y entender el **modelo interno de rendering** del `repo-server` lo bastante bien como para predecir qué funcionará y qué no — en particular, por qué los **hooks de Helm no se ejecutan igual** que con `helm install`.

## Temas y subtemas

1. **Plain YAML / directory** — `source.directory.recurse`, `include/exclude`, Jsonnet aquí dentro.
2. **Helm**
   - Campos del CR: `source.helm.values`, `valueFiles`, `releaseName`, `parameters`, `fileParameters`, `passCredentials`.
   - **Cómo Argo CD renderiza Helm**: `helm template` + apply, no `helm install`.
   - Consecuencias: no hay Secret `sh.helm.release.v1.*`, `helm list` no ve nada, `helm test` no corre.
   - Hooks de Helm (`pre-install`, `pre-upgrade`...) → quedan en **limbo** o se mapean a Argo CD hooks (parcial).
3. **Kustomize** — `source.kustomize.namePrefix/nameSuffix`, `images`, `commonLabels`, `commonAnnotations`, `patches`, `replicas`, `components`.
4. **Jsonnet** (visto por encima) — útil cuando ya existe código Jsonnet; no se recomienda introducirlo nuevo en 2026.
5. **Multi-source Applications** — `spec.sources: []` con `ref` para "chart base en repo A + values file en repo B".
6. **Config Management Plugins (CMPs)** — para herramientas no soportadas nativamente (`cdk8s`, `cue`, `tanka`, `helmfile`, scripts propios).

## Conceptos internos (fundamentos)

- Quien renderiza es el **`repo-server`**. Clona el repo, resuelve la revisión, y ejecuta `helm template`, `kustomize build`, `jsonnet` o el CMP correspondiente, devolviendo YAML plano al `application-controller`.
- La abstracción es: *source → plain Kubernetes manifests → diff vs cluster → apply*. Todo lo que sea estado propio de la herramienta (releases de Helm, secrets de ownership) **no existe** desde la perspectiva de Argo CD.
- Los **hooks de Helm** se traducen vía anotaciones: Argo CD reconoce `helm.sh/hook: pre-install, pre-upgrade` y lo mapea a `argocd.argoproj.io/hook: PreSync`. Los `delete-policies` y `weights` **no se traducen 1:1**, y los hooks de `test` no se ejecutan.
- Para operaciones ordenadas (migraciones DB, warmups) la vía canónica bajo Argo CD son **sync waves + resource hooks nativos**, no hooks de Helm.
- Multi-source permite el patrón **"upstream chart + values propios"** sin necesidad de forkear ni crear un chart wrapper — pero introduce dos revisiones a seguir.

## Competencias

- **Conceptual** — justificar la elección del tipo de source para un caso dado; explicar por qué `helm install` ≠ Argo CD rendering y qué cambia en operación.
- **Operativa** — escribir Applications con cada tipo de source; combinar un chart upstream con un `values.yaml` propio en otro repo mediante multi-source.
- **Arquitectónica** — decidir cuándo introducir un CMP (y aceptar su costo operativo) vs. mantenerse en herramientas nativas; diseñar la convención de carpetas y referencias.

## Ejemplos

- [`examples/01-helm-source-with-values`](examples/01-helm-source-with-values/) — Application que apunta a un chart Helm con `values`, `valueFiles` y `parameters`.
- [`examples/02-kustomize-with-image-override`](examples/02-kustomize-with-image-override/) — Application Kustomize con override de imagen, prefix y label comunes.
- [`examples/03-multi-source-chart-plus-values`](examples/03-multi-source-chart-plus-values/) — chart upstream + `values.yaml` en otro repo (feature multi-source).

## Actividades

- [`activities/01-deploy-capstone-via-helm-source`](activities/01-deploy-capstone-via-helm-source/) — **guided-lab**: desplegar una app de capstone en `kind` + Argo CD vía Helm source.
- [`activities/02-multi-source-pattern`](activities/02-multi-source-pattern/) — **independent**: separar chart y values en dos repos y combinarlos con `spec.sources`.

## Entregables

- Capstone desplegado en `kind` vía **Helm source** con `valueFiles` externos.
- Application **multi-source** que referencia un chart upstream (bitnami u otro público) y los values propios.
- Nota breve respondiendo: *¿por qué el hook `pre-install` de Helm no te sirve bajo Argo CD, y cuál es la alternativa?*

## Criterios de evaluación

- **Conceptual** — explicar el flujo "render → diff → apply" y por qué no hay Secret de release de Helm.
- **Operativa** — escribir una Application que mezcle `valueFiles` + `parameters` + override de `image.tag`; levantar la multi-source y mostrar que sincroniza.
- **Arquitectónica** — defender la elección de source y de pattern (fork del chart vs multi-source vs CMP) para un escenario dado.

## Recursos

Ver [`resources/links.md`](resources/links.md).
