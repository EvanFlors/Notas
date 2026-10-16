# Actividad 02 — Preview environments por PR (independent)

## 1. Identificación

- **ID:** `argo-07-02-pr-preview-environments`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `07-applicationsets-and-generators`
- **Dificultad:** intermediate
- **Duración estimada:** 75–110 min
- **Tipo:** independent

## 2. Contexto

Tu plataforma necesita **preview environments por PR**: cada vez que alguien abre un PR etiquetado `preview`, aparece un namespace `myapp-pr-<N>` con la aplicación en el commit del PR; cuando el PR se cierra, el namespace y todos sus recursos desaparecen.

Esto habilita QA/UX dar feedback *antes* del merge, y es imposible de hacer razonablemente con `app-of-apps` clásico.

En esta actividad **independiente** diseñas y entregas:

1. Un `ApplicationSet` real con generator `pullRequest.github` (listo para producción).
2. Un `ApplicationSet` de **mock** con generator `git.files` que simule el shape de eventos PR, para desarrollo local sin credenciales de GitHub.

No se te dan los manifests. Diseñas tú.

## 3. Objetivos

Al terminar deberías poder:

- Explicar y aplicar el patrón PR preview.
- Diseñar nombres y namespaces que no colisionen entre PRs ni con recursos cluster-scoped.
- Justificar por qué `preserveResourcesOnDeletion: false` es correcto *para previews*.
- Entregar un modo mock que funcione sin GitHub (file generator o list generator).

## 4. Prerrequisitos

- Actividad `01-env-per-folder-appset` completada.
- `git`, `kubectl`, `python3`.
- **Opcional** para el modo "real": token de GitHub con `repo` y Argo CD con `applicationset-controller`.

**Costos:** ninguno si usas el modo mock.

## 5. Instrucciones

### 5.1 Entregables

Al terminar, en `/tmp/argo-07-02/` debes tener:

```
/tmp/argo-07-02/
├── appset-github.yaml       # ApplicationSet con generator pullRequest.github
├── appset-mock.yaml         # ApplicationSet con generator git.files (mock)
├── mock-repo/               # repo git local con PRs simulados como archivos
│   └── pulls/
│       ├── 101.yaml         # {number: 101, branch: feat/x, head_sha: abc...}
│       ├── 102.yaml
│       └── 103.yaml
└── NOTES.md                 # (opcional) tu razonamiento
```

### 5.2 Restricciones

- Ambos `ApplicationSet` deben usar `goTemplate: true` + `goTemplateOptions: ["missingkey=error"]`.
- El `metadata.name` debe depender de `{{.number}}` y ser único.
- El `destination.namespace` debe ser `myapp-pr-{{.number}}` (o equivalente determinístico).
- `syncPolicy.automated.prune: true` + `syncPolicy.automated.selfHeal: true`.
- NO `preserveResourcesOnDeletion: true` — queremos que al cerrar el PR desaparezca todo.
- El `appset-github.yaml` debe filtrar por `labels: ["preview"]` y usar `tokenRef`.
- El `appset-mock.yaml` debe usar un repo con `file://` y `files:` apuntando a `pulls/*.yaml`.

### 5.3 Pistas

- Para `appset-mock.yaml`, el shape mínimo del archivo YAML por PR es:
  ```yaml
  number: 101
  branch: feat/example
  head_sha: deadbeefcafebabedeadbeefcafebabedeadbeef
  ```
- `git.files` **mergea las claves top-level** del YAML con el contexto del template → `{{.number}}`, `{{.branch}}`, `{{.head_sha}}` quedan disponibles.
- Para probar el ciclo "cerrar PR" en el mock, basta con **borrar** el archivo `pulls/<N>.yaml` y commitear. El controller dejará de generar esa App → se borra.
- Para evitar colisiones de recursos cluster-scoped (p. ej. `ClusterRoleBinding`), nombralos con sufijo `{{.number}}` en el `source.path`.

### 5.4 Flujo sugerido

1. Crea el skeleton con `bash starter/build-mock-infra.sh` (crea el `mock-repo/` con 3 PRs ejemplo).
2. Diseña `appset-mock.yaml` y guárdalo en `/tmp/argo-07-02/`.
3. Diseña `appset-github.yaml` basado en el ejemplo `03-pullrequest-preview-env` pero adaptado a tu escenario.
4. (Opcional) Aplica el mock en kind+argocd y verifica que aparecen 3 Applications.
5. Borra `pulls/101.yaml`, commitea, espera, verifica que `myapp-pr-101` desaparece.
6. Ejecuta `bash tests/validate.sh`.

### 5.5 Validar

```bash
bash /Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy/courses/argocd-gitops/07-applicationsets-and-generators/activities/02-pr-preview-environments/tests/validate.sh
```

El script valida los manifests y, si hay cluster, verifica Applications generadas.

## 6. Resultado esperado

- `appset-github.yaml` y `appset-mock.yaml` ambos válidos.
- `mock-repo/pulls/{101,102,103}.yaml` con el shape correcto.
- Si hay cluster: 3 Applications `myapp-pr-101/102/103` con label `generated-by=pr-preview`.

## 7. Criterios de aceptación

- [ ] Dos ApplicationSets correctamente diseñados (GitHub real + mock file-based).
- [ ] Ambos usan `goTemplate: true` + `missingkey=error`.
- [ ] Nombres y namespaces únicos por PR.
- [ ] `pullRequest` generator filtra por label `preview` y usa `tokenRef`.
- [ ] `preserveResourcesOnDeletion` **no** está en `true`.
- [ ] `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `preserveResourcesOnDeletion: true` sería un *error* para previews pero *correcto* para un ambiente de producción generado por ApplicationSet?
2. Imagina 50 PRs abiertos simultáneamente. ¿Qué recursos del cluster pueden saturarse? ¿Cómo lo mitigarías (cuotas, filtros, label requerido)?
3. El PR generator con `requeueAfterSeconds: 60` consulta GitHub cada minuto. ¿Qué pasa con el rate limit? ¿Cómo lo mitiga una organización con 100 repos usando este patrón?
4. ¿Por qué el shape mock con `number/branch/head_sha` **es** representativo del shape real? Lee la lección sección 7.
5. Si un PR se abre con cambios **destructivos** (p. ej. drop de una tabla), ¿qué protecciones añades para que el preview no toque recursos compartidos reales?

## 10. Extensiones (opcional)

- **E1** — Añade `strategy: RollingSync` para que las previews no se desplieguen todas a la vez.
- **E2** — Diseña un `AppProject` llamado `previews` con `destinations: ["myapp-pr-*"]` y aplícalo.
- **E3** — Añade `notifications.argoproj.io/subscribe.on-sync-succeeded.slack: '#pr-previews'` como annotation parametrizada.

## 11. Limpieza

```bash
# Si aplicaste en argocd:
kubectl -n argocd delete applicationset myapp-pr-previews-mock --ignore-not-found
kubectl -n argocd delete applicationset myapp-pr-previews --ignore-not-found
for n in $(kubectl get ns -o name | grep -E 'myapp-pr-' || true); do
  kubectl delete "$n" --ignore-not-found
done

rm -rf /tmp/argo-07-02
```
