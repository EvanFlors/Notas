# k8s-05 — Config, Secrets, env y volúmenes básicos

## Identificación

- **ID:** `k8s-05-config-secrets-env-volumes-basics`
- **Curso:** `kubernetes`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `k8s-03-pods-deployments-replicasets` (y por transitividad `k8s-01`, `k8s-02`).

## Objetivo

Separar **configuración** y **secretos** del código y del container image, usando los primitivos nativos de Kubernetes (`ConfigMap`, `Secret`, `Volume`, `downwardAPI`) con criterio operativo y de seguridad. Al terminar deberías poder decidir *cómo* se consume cada tipo de dato (env var vs archivo montado vs projected volume), justificar por qué un `Secret` **no** está cifrado por default en etcd, y auditar que ningún secreto se filtra por logs o por `env` dump.

## Alcance

Este módulo cubre:

- **ConfigMap**: creación por `--from-literal`, `--from-file`, `--from-env-file`; consumo vía `env`, `envFrom` y `volumeMounts`.
- **Secret**: tipos `Opaque`, `docker-registry`, `kubernetes.io/tls`, `kubernetes.io/service-account-token`; consumo vía env y volume; el detalle **base64 ≠ encriptación**.
- **Volúmenes básicos**: `emptyDir`, `hostPath` (y por qué evitarlo), `projected`, `downwardAPI`.
- **Encryption at rest** del `kube-apiserver` sobre etcd (`EncryptionConfiguration`).
- **Integración con secret managers externos** (walkthrough, no instalación): External Secrets Operator (ESO), Secrets Store CSI Driver, Vault Agent Injector.
- Patrón **projected volume** para agrupar múltiples fuentes atómicamente.

Lo que **no** cubre (se verá después):

- `PersistentVolume`, `PersistentVolumeClaim`, `StorageClass` → `k8s-08-storage`.
- Políticas de admisión que *obliguen* a usar `secretKeyRef` o prohíban `env` para secretos → `k8s-12-rbac-serviceaccounts-admission-policy`.
- Firma de imágenes y supply-chain → `k8s-16-security-hardening-and-supply-chain`.

## Materiales

- **`theory/lesson.md`** — 12 secciones.
- **`examples/`**:
  - `01-configmap-env-and-mount/` — ConfigMap consumido como env y como archivo; demuestra las dos modalidades y sus trade-offs.
  - `02-secret-as-file-vs-env/` — Secret via env vs volume mount; demuestra en vivo que **base64 ≠ encrypted** y que env vars se filtran trivialmente.
  - `03-external-secrets-operator-intro/` — walkthrough (sin instalación) de ESO, Secrets Store CSI Driver y Vault Agent Injector.
- **`activities/`**:
  - `01-config-and-secret-for-capstone/` (guided-lab) — una app Python leyendo config desde ConfigMap y password desde Secret montado como archivo.
  - `02-why-base64-is-not-encryption/` (independent / análisis) — el estudiante demuestra con `kubectl` y `base64 -d` que un `Secret` es cleartext, redacta `ANALYSIS.md` y recomienda ESO.
- **`resources/links.md`** — documentación oficial y lecturas complementarias.

## Temas y subtemas

1. **ConfigMap**
   - Creación: `--from-literal`, `--from-file`, `--from-env-file`.
   - Consumo: `env.valueFrom.configMapKeyRef`, `envFrom`, `volumeMounts`.
   - Hot-reload cuando se monta como volumen (y por qué un `env` *no* se actualiza).
2. **Secret**
   - Tipos: `Opaque`, `kubernetes.io/dockerconfigjson`, `kubernetes.io/tls`, `kubernetes.io/service-account-token`, `bootstrap.kubernetes.io/token`.
   - `stringData` vs `data` (y la trampa del base64 implícito).
   - Consumo vía env y vía volume.
3. **Volúmenes básicos**
   - `emptyDir` (y `emptyDir.medium: Memory` como tmpfs).
   - `hostPath` — por qué evitar en producción (nodo acoplado, escalada por path traversal).
   - `projected` — agrupa `secret`, `configMap`, `downwardAPI` y `serviceAccountToken`.
   - `downwardAPI` — exponer `metadata.labels`, `metadata.name`, `status.podIP`.
4. **Base64 ≠ encryption**
   - Qué guarda etcd exactamente; cómo verlo.
   - `EncryptionConfiguration` del `kube-apiserver` (aescbc, aesgcm, secretbox, kms, kms v2).
5. **Secret managers externos**
   - **External Secrets Operator (ESO)**: `SecretStore` + `ExternalSecret` → sincroniza desde Vault / AWS Secrets Manager / GCP SM / Azure KV.
   - **Secrets Store CSI Driver**: monta secretos como archivos efímeros sin escribir un `Secret` nativo (opcionalmente sí, para que lean controllers que esperan `secretKeyRef`).
   - **Vault Agent Injector**: sidecar que renderiza secretos en un `emptyDir` para la app.

## Conceptos internos (fundamentos)

- Un `Secret` **vive en etcd como cleartext base64** salvo que se habilite `EncryptionConfiguration` en el `kube-apiserver`. `base64` es un *encoding*, no un *cifrado*: lo decodifica cualquiera con `base64 -d`. Un atacante con acceso a los snapshots de etcd ve los secretos tal cual.
- Un **Secret consumido como env var** aparece en:
  - `kubectl describe pod` (campo `Environment`).
  - Cualquier `ps e <pid>` dentro del contenedor (otros procesos lo leen).
  - Volcados de "all env" que apps vomitan al arrancar o al crashear (`CrashLoopBackOff` con `print(os.environ)` o `env` en error handlers).
  - Child processes heredados.
- Un **Secret consumido como volume** vive solo en el `tmpfs` del Pod (no toca disco del nodo), es visible solo a procesos con acceso al mount point, y **se actualiza en vivo** (con delay del kubelet sync period, ~1 min) cuando cambia el `Secret`.
- `envFrom` toma **todas** las claves del `ConfigMap`/`Secret` y las convierte en env vars con sus mismos nombres: cómodo, pero sin posibilidad de renombrar; una clave rara puede ser un nombre de env inválido.
- `projected` agrupa varias fuentes en un solo mount. Útil para que *rotaciones parciales* sean atómicas (los files aparecen juntos tras un `rename(2)` del kubelet).
- `hostPath` **acopla el Pod al nodo**: si el Pod reaparece en otro nodo, su "estado" no está. Peor aún, un `hostPath` sobre `/`, `/var/run/docker.sock` o `/etc` convierte un contenedor comprometido en un *root sobre el nodo* trivial. Casi siempre se puede reemplazar por `emptyDir`, un `ConfigMap`, un `Secret` o un `PersistentVolume` (ver `k8s-08`).

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `data` y `stringData` en Secrets. Explicar por qué `base64 ≠ encryption` y qué habilita realmente `EncryptionConfiguration`. Explicar cuándo preferir `projected` sobre `secret` + `configMap` separados. |
| Operativa | Crear ConfigMaps y Secrets con los tres métodos (`--from-literal`, `--from-file`, `--from-env-file`). Consumirlos como `env`, `envFrom` y `volumeMounts`. Decodificar un Secret con `kubectl get secret -o jsonpath`. |
| Arquitectónica | Decidir, para una app dada, qué datos van en ConfigMap, cuáles en Secret, y si corresponde delegar los Secrets a un secret manager externo (ESO/CSI/Vault). Justificar por qué `hostPath` no entra en producción. |

## Entregables

- La app del capstone (Python mínimo) **leyendo config desde ConfigMap** (vía `envFrom`) y la **DB password desde un Secret montado como archivo** en `/etc/app/secret/db-password`, verificable con `kubectl exec`.
- Un `ANALYSIS.md` entregado por la actividad 02 que demuestra, con comandos reales y su salida pegada, que el Secret está en cleartext y recomienda ESO con argumentos.
- Los dos `tests/validate.sh` deben pasar.

## Criterios de evaluación

- **Explicar los riesgos de Secrets como env vars** con al menos tres vectores (`describe pod`, `/proc/<pid>/environ`, logs de crash, procesos hijos).
- Justificar la elección de `volumeMounts` sobre `env` para secretos sensibles, y por qué un `projected` es preferible a dos mounts.
- Diagnosticar un cluster que *parece* tener Secrets "seguros" cuando en realidad solo tiene base64 (ver actividad 02).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo. No saltar las secciones 7–9 (base64, encryption at rest, secret managers).
2. Reproduce `examples/01-configmap-env-and-mount/`.
3. Reproduce `examples/02-secret-as-file-vs-env/` **entero**, especialmente la parte de `base64 -d` sobre `kubectl get secret -o jsonpath`.
4. Lee `examples/03-external-secrets-operator-intro/` (no es necesario instalar nada).
5. Haz `activities/01-config-and-secret-for-capstone/`.
6. Haz `activities/02-why-base64-is-not-encryption/` y entrega `ANALYSIS.md`.
7. Responde las preguntas de evaluación sin consultar.

## Siguiente

→ `k8s-06-workloads-deep-statefulset-daemonset-jobs`: cuando el workload tiene *identidad* (DBs, colas), ni Deployment ni ConfigMap son suficientes.
