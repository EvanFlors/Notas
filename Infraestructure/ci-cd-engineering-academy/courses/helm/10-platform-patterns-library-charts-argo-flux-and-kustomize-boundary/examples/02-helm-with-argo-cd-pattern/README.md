# Ejemplo 02 — Helm con Argo CD: patrón `Application`

> Este ejemplo es **documental**: muestra el manifiesto `Application` que Argo CD usa para consumir un chart Helm, y las trampas asociadas. No se despliega aquí (el curso **argocd** lo cubre entero). Si quieres probarlo, instala Argo CD en `kind` y aplica `application.yaml`.

## Qué muestra

- Cómo apuntar un `Application` a un chart Helm (OCI o HTTP).
- Diferencia entre `source.helm.values`, `source.helm.valueFiles` y `source.helm.parameters`.
- Qué cambia porque Argo CD **no ejecuta `helm install`**.

## El manifest

Ver `application.yaml`.

Puntos clave:

- `source.chart` + `source.repoURL` + `source.targetRevision` identifican el chart y su versión (SemVer del chart, no de la app).
- `source.helm.releaseName` define el *release name* que Argo CD usará al renderizar. Si no lo pones, usa el `metadata.name` del `Application` — y eso cambia los nombres generados por los helpers `fullname`.
- `source.helm.valueFiles` apunta a `values-prod.yaml` dentro del chart; si tus overrides están fuera del chart, usa `multiple sources` (feature estable desde Argo CD 2.6+).
- `source.helm.values` acepta un bloque YAML inline — útil, peligroso: no vive en Git como un file.
- `source.helm.parameters` es equivalente a `--set` — mismo coste de reproducibilidad.

## Las trampas (lo que la lección 4 detalla)

1. **Sin Secret de release de Helm.** Argo renderiza y aplica. `helm list -n X` no verá nada. Rollback = `argocd app rollback` o `git revert`.
2. **Hooks de Helm → hooks de Argo.** `helm.sh/hook: pre-install` se mapea a `argocd.argoproj.io/hook: PreSync`. Weights y delete-policies no se traducen 1:1. Verifica tus migraciones DB antes de confiar.
3. **`helm test`** no corre automático. Programa un Job post-sync si lo necesitas (syncwave + annotation).
4. **No pases flags de la CLI de Helm**: `--atomic`, `--wait`, `--timeout` no aplican. Usa `syncPolicy`, `retry` y `syncOptions` de Argo.
5. **ApplicationSet** es el patrón correcto para N entornos:
   ```yaml
   generators:
     - list:
         elements:
           - env: dev
           - env: stg
           - env: prod
   template:
     spec:
       source:
         helm:
           valueFiles: ["values-{{env}}.yaml"]
   ```

## Verificación local sin cluster

```bash
helm version --short
# El manifest es solo YAML; valida sintaxis con:
python3 -c "import yaml,sys; list(yaml.safe_load_all(open('application.yaml'))); print('OK: valid YAML')"
```

## Puente al curso Argo CD

El manifest completo (sync waves, finalizers, retry policy, `multiple sources`) y la operativa (`argocd app sync`, drift detection, ApplicationSet) viven en el curso **argocd**. Aquí solo nos interesa cómo **Argo consume un chart Helm** y qué cambia en el modelo de Helm cuando lo hace.

## Limpieza

Nada que limpiar — este ejemplo es solo documentación y YAML estático.
