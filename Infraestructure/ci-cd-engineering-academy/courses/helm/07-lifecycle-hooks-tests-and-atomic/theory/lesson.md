# Lección — Lifecycle de un release: hooks, tests y atomic

## 1. Qué problema resuelve el lifecycle de Helm

`helm install` o `helm upgrade` no son operaciones puntuales: cada una es una **secuencia** de pasos que puede fallar en cualquier punto. En un sistema real, hay cosas que **tienen que** pasar antes de que los nuevos Pods arranquen (migración de esquema), cosas que **tienen que** pasar después (warm-up, notificación, test), y cosas que **tienen que** pasar antes de borrar un release (backup, drain).

Helm expone estos puntos con dos mecanismos complementarios:

- **Hooks** — recursos K8s que Helm ejecuta en momentos específicos del lifecycle del release.
- **Flags de espera y rollback** — `--wait`, `--timeout`, `--atomic`, `--cleanup-on-fail`.

El resto del módulo es: dominar ambos mecanismos y, sobre todo, **saber cuándo no usarlos**.

## 2. Los siete tipos de hook

Un hook es un manifiesto normal con la anotación `helm.sh/hook`. Los siete valores válidos son:

| Hook            | Cuándo corre                                                                 |
|-----------------|------------------------------------------------------------------------------|
| `pre-install`   | Antes de aplicar los manifiestos de la primera instalación del release.      |
| `post-install`  | Tras aplicar manifiestos y (si se usó `--wait`) tras `Ready`.                |
| `pre-upgrade`   | Antes de aplicar los manifiestos de una revisión que no sea la primera.     |
| `post-upgrade`  | Tras aplicar los manifiestos de un upgrade.                                 |
| `pre-delete`    | Antes de empezar a borrar los recursos del release.                         |
| `post-delete`   | Tras borrar los recursos del release.                                       |
| `test`          | Al ejecutar `helm test <release>` (no corre automáticamente).               |

Un mismo manifiesto puede declarar varios hooks separados por coma: `pre-install,pre-upgrade` es el idiom clásico para una migración de esquema (vale tanto para la primera instalación como para cada upgrade subsiguiente).

## 3. Weight y ordenamiento

Dentro de una misma fase (p. ej. `pre-upgrade`), varios hooks se ordenan por **weight ascendente**. El weight es un string decimal (Helm lo parsea como entero), negativo o positivo. Convención práctica:

```yaml
annotations:
  "helm.sh/hook": pre-upgrade
  "helm.sh/hook-weight": "-5"   # corre antes
```

Si dos hooks comparten weight, Helm los ordena por `kind` y nombre; apoyarse en ese tie-breaker es frágil, mejor asignar weights distintos cuando el orden importa.

El weight **no se comparte entre fases**: un hook `pre-install` con weight 10 y uno `post-install` con weight -10 corren en sus fases respectivas y no interactúan.

## 4. Delete policies

El ciclo de vida del hook dentro del cluster lo controla `helm.sh/hook-delete-policy`:

- `before-hook-creation` (default) — si el recurso ya existe (p. ej. un `Job` con el mismo nombre de la ejecución anterior), lo borra antes de recrearlo.
- `hook-succeeded` — borra el recurso tras completar con éxito.
- `hook-failed` — borra el recurso tras fallar.

El combo pragmático para la mayoría de `Job` hooks es:

```yaml
"helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

Esto garantiza (a) idempotencia entre upgrades y (b) un cluster limpio tras éxito, dejando los Jobs fallidos **in situ** para depurar (`kubectl logs job/...`).

## 5. Caso canónico: migración de base de datos

Casi todas las apps con DB necesitan ejecutar una migración de esquema antes de que la nueva versión arranque. En Helm esto se modela como un `Job` con hooks `pre-install,pre-upgrade`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mychart.fullname" . }}-migrate
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          command: ["/bin/sh", "-c", "alembic upgrade head"]
```

Nota: Helm **espera** a que el `Job` termine antes de continuar. Si el `Job` falla, el install/upgrade falla.

## 6. Otros casos de hook

- **Backup antes de upgrade mayor:** `pre-upgrade` que lanza un `Job` que hace `pg_dump` a un bucket.
- **Warm-up global:** `post-install,post-upgrade` que entrena un cache compartido (p. ej. un `Job` que llama a un endpoint de precalentamiento).
- **Drain / notificación:** `pre-delete` que llama a un webhook externo "release X siendo eliminado".
- **Limpieza:** `post-delete` para borrar recursos out-of-band que no están gestionados por el release (buckets temporales, DNS).

**Antipatrón:** usar `post-install` para instalar CRDs. Las CRDs van en `crds/` o en un chart separado (ver `helm-03`).

## 7. `helm test`: smoke test del release

`templates/tests/*.yaml` contiene Pods o Jobs con `helm.sh/hook: test`. No se instalan con `helm install`; se ejecutan sólo con `helm test <release>`. Convención:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-connection"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox:1.36
      command: ['wget']
      args: ['--spider', '--timeout=5', 'http://{{ include "mychart.fullname" . }}:{{ .Values.service.port }}/']
```

Si el pod sale con 0, el test pasa. Si no, falla. `helm test` se puede ejecutar las veces que haga falta sin tocar la revisión del release.

## 8. `--wait`, `--timeout`

- `--wait` hace que Helm bloquee hasta que **todos** los recursos del release estén `Ready` (Deployment: `.status.readyReplicas == .spec.replicas`; Service: ClusterIP asignado; PVC: `Bound`; …). Sin `--wait`, `helm install` retorna en cuanto el `kubectl apply` termina — los Pods pueden estar aún `Pending`.
- `--timeout` acota la espera. Default: `5m`. En CI vale la pena bajarlo o subirlo según la app.

Sin `--wait`, hooks `post-install`/`post-upgrade` corren tras el apply pero **no esperan** que los recursos estén listos. Con `--wait`, Helm espera, luego corre los `post-*` hooks.

## 9. `--atomic` como default en CI/CD

`--atomic` = `--wait` + rollback automático si algo falla. En caso de que la revisión sea la #1 (no hay nada a lo que hacer rollback), equivale a `--wait` + `uninstall` en fallo.

```sh
helm upgrade --install myapp ./chart \
  --namespace myns --create-namespace \
  --atomic --timeout 5m \
  --values values.yaml
```

En un pipeline, esto garantiza que:
- Nunca se queda una revisión parcial aplicada.
- Si la nueva versión no reporta `Ready` en el timeout, se vuelve a la anterior.
- El estado del release en el Secret es consistente con el estado real del cluster.

Nota de versión: en **Helm 4** el flag `--atomic` sigue funcionando pero emite un warning sugiriendo `--rollback-on-failure`. Son equivalentes; el curso usa `--atomic` por consistencia con la documentación histórica.

Trade-off: `--atomic` **oculta** diagnóstico (el rollback borra evidencia). Patrón recomendado para debug local: correr sin `--atomic`, inspeccionar, y re-correr con `--atomic` en CI.

## 10. `--cleanup-on-fail`

Flag adicional: en un upgrade fallido, elimina los recursos **recién creados por esta revisión** (no los que ya existían). Útil cuando una revisión introduce, p. ej., un nuevo `Deployment` que falla; sin `--cleanup-on-fail` el objeto queda huérfano en el namespace.

`--atomic` ya implica un rollback (que lleva al estado previo), pero combinarlos no está de más en pipelines estrictos.

## 11. Criterio: hook vs initContainer vs operator

Un hook no es la respuesta correcta siempre. Reglas de dedo:

| Necesidad                                                              | Mejor en                                       |
|------------------------------------------------------------------------|------------------------------------------------|
| "Debe pasar una vez por release y bloquear al rollout entero."          | **Hook** (`pre-install,pre-upgrade` + `Job`).  |
| "Debe pasar antes de que *este Pod* esté `Ready`."                     | **`initContainer`** del Pod en cuestión.       |
| "Es idempotente y específica de un Pod (p. ej. descarga de modelo)."   | **`initContainer`**.                           |
| "Es una tarea periódica o reactiva (reconciliación continua)."         | **Operator** con CRD.                          |
| "Debe orquestar múltiples apps con lógica compleja (failover, HA)."    | **Operator** (CloudNativePG, Strimzi).         |
| "Nunca se repite y es out-of-band del cluster (DNS, bucket)."          | **Hook** `post-install` o pipeline externo.    |

Antipatrones comunes:
- Migración de DB como `initContainer` del Deployment principal → se ejecuta N veces en paralelo (una por replica).
- Operator "casero" para una tarea que corre una vez por release → sobre-ingeniería.
- Hook para algo que debería ser un cron (CronJob regular, no un hook).

## 12. Internals: hooks no son "parte" del release

Puntos sutiles que suelen causar sorpresas:

- `helm get manifest <rel>` muestra los **recursos del release**, no los hooks. `helm get hooks <rel>` sí los lista.
- Un hook con `hook-succeeded` **desaparece** del cluster tras éxito. Es correcto que `kubectl get job` no lo muestre después.
- Si un hook queda en el cluster (p. ej. porque falló y la delete-policy no lo cubre), Helm *no* lo gestiona en futuras revisiones excepto por el `before-hook-creation` que lo borra al re-crearlo.
- `helm uninstall` no corre `test` hooks; sí corre `pre-delete` y `post-delete`.
- Argo CD y Flux implementan "sus propios" hooks (`argocd.argoproj.io/hook`, phases de Flux); los hooks de Helm siguen funcionando pero el ordering combinado puede volverse opaco — en entornos GitOps conviene documentar explícitamente qué hooks viven en el chart y qué sync-waves en el GitOps engine.
