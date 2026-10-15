# Lección: Config, Secrets, env y volúmenes básicos

> **ID:** `k8s-05-config-secrets-env-volumes-basics` · **Nivel:** fundamentos · **Duración:** 3 h
> **Prerrequisitos:** `k8s-03-pods-deployments-replicasets`.

---

## 1. Introducción intuitiva

Hasta aquí tus Pods han sido monolíticos: la imagen traía la aplicación, su configuración y hasta las credenciales de la base de datos. Funciona para un demo. Rompe en cuanto necesitas **la misma imagen** en dev, staging y prod — o cuando un auditor te pregunta "¿dónde está la DB password?" y la respuesta correcta no puede ser "en el Dockerfile".

Kubernetes separa el **artefacto inmutable** (el container image) de la **configuración por entorno** (ConfigMap) y de los **secretos** (Secret), que se inyectan al Pod *en el momento de scheduling*. La misma imagen `app:1.2.3` puede correr en dev con `LOG_LEVEL=debug` y en prod con `LOG_LEVEL=warn` sin reconstruir ni reetiquetar.

El giro del módulo es que, cuando ves `kubectl create secret`, es muy fácil creer que acabas de hacer algo seguro. **No.** Un Secret es un objeto de la API con los valores codificados en **base64** — un *encoding*, no un *cifrado*. Cualquiera con permisos `get secrets` ve los valores. Y por default, `etcd` los guarda igual: base64 cleartext. Este módulo cubre esa trampa con detalle y te enseña cómo mitigarla (encryption at rest + secret managers externos).

---

## 2. Fundamentos

### 2.1 ConfigMap y Secret son objetos de la API, no un almacén

Ambos viven en etcd como cualquier otro recurso. Tienen `metadata`, `data` y, en el caso de Secret, también `stringData` (azúcar sintáctico que el API server convierte a `data`). Son **namespaced**: `kubectl get configmap -n <ns>`.

```
┌─────────────────┐
│  kubectl apply  │
└────────┬────────┘
         │
         ▼
┌───────────────────┐    ┌─────────────┐
│  kube-apiserver   │ ─> │    etcd     │  (ConfigMap: plain; Secret: base64)
└────────┬──────────┘    └─────────────┘
         │ al scheduling de un Pod que los referencia
         ▼
┌───────────────────┐
│     kubelet       │  monta en tmpfs del Pod o inyecta como env var
└───────────────────┘
```

**Idea central**: no vive en el Pod — vive en el cluster. El Pod lo *referencia*. Si borras el Pod, el ConfigMap/Secret sigue ahí. Si borras el ConfigMap/Secret, Pods ya corriendo lo tienen cacheado hasta su siguiente sync.

### 2.2 "base64 ≠ encryption" — la trampa canónica

Secret guarda sus valores codificados en base64:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db
type: Opaque
data:
  password: c3VwZXItc2VjcmV0   # <- esto NO es cifrado, es base64 de "super-secret"
```

`base64 -d` lo revierte en microsegundos. El propósito del encoding no es confidencialidad: es que valores binarios o con caracteres especiales entren limpios en YAML.

Si quieres **cifrado real en reposo**, hay que configurar `EncryptionConfiguration` en el `kube-apiserver` (sección 9). Si no, cualquier snapshot de etcd (o un backup mal custodiado) es un leak de todos tus secretos.

### 2.3 Dos formas de consumo: env var o archivo

Ambos tipos se pueden consumir de dos maneras:

- **env var** (`env.valueFrom.*` o `envFrom`): rápido, cómodo, **arriesgado para secretos** (sección 6).
- **volume mount** (archivos en un `tmpfs`): la app lee el valor haciendo `open(2)`. Preferido para secretos.

Un ConfigMap suele ser configuración declarativa: endpoints, flags, timeouts. Como no es sensible, los env vars suelen estar bien. Un Secret suele ser credencial: casi siempre quieres montarlo como archivo.

---

## 3. Contexto histórico

- **2015** — Kubernetes 1.0: Secrets existen desde el principio; en etcd como base64 **sin cifrar**. Nadie se escandalizó porque el modelo mental seguía siendo "cluster privado detrás de un firewall".
- **2017** — v1.7: `EncryptionConfiguration` llega como alpha. Primeros proveedores: `aescbc`, `secretbox`, `aesgcm` y `kms` (externo).
- **2019** — v1.13: encryption at rest estable; `kms` provider v1 estable.
- **2020** — Aparece **External Secrets Operator** (ExternalSecretsIO / GoDaddy inicialmente) para evitar que los equipos escriban Secrets a mano desde Vault/AWS SM.
- **2021** — **Secrets Store CSI Driver** GA; permite montar secretos desde managers externos como *archivos efímeros* sin crear un Secret nativo.
- **2022–2023** — `kms` v2 (más eficiente, menos llamadas al KMS externo); `apiVersion: apiserver.config.k8s.io/v1`.
- **2024+** — Pod Security Admission `restricted` no prohíbe secretos como env, pero sí restringe cosas tangencialmente útiles (`hostPath`, por ejemplo).

Lecciones acumuladas: el 90 % de los leaks de secretos en K8s son por (a) `env` dumps a logs, (b) etcd backups sin cifrar, (c) RBAC laxo `get secrets` a demasiados `ServiceAccount`.

---

## 4. ConfigMap: creación y consumo

### 4.1 Tres formas de crear

**Literal** — para dos o tres claves rápidas:

```bash
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-literal=HTTP_PORT=8080 \
  --dry-run=client -o yaml
```

**From-file** — una clave por archivo (nombre de clave = nombre de archivo):

```bash
kubectl create configmap nginx-conf --from-file=nginx.conf
# genera data.nginx.conf = <contenido del archivo>
```

**From-env-file** — un archivo `KEY=VALUE` por línea; cada línea una clave:

```bash
cat > app.env <<'EOF'
LOG_LEVEL=info
HTTP_PORT=8080
FEATURE_X=on
EOF
kubectl create configmap app-config --from-env-file=app.env
```

Las tres emiten el mismo objeto base. Usa `--dry-run=client -o yaml` para capturar el YAML y versionarlo en Git (GitOps, `k8s-18`).

### 4.2 Consumo: `env`, `envFrom`, `volumeMounts`

```yaml
# selectivo: una clave → una env var (puedes renombrar)
env:
  - name: APP_LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: LOG_LEVEL

# masivo: todas las claves como env vars con su nombre tal cual
envFrom:
  - configMapRef:
      name: app-config

# archivo: cada clave es un archivo en el mountPath
volumeMounts:
  - name: cfg
    mountPath: /etc/app
    readOnly: true
volumes:
  - name: cfg
    configMap:
      name: app-config
```

Diferencias prácticas:

- **`env`**: la app lee `os.environ["APP_LOG_LEVEL"]`. No se actualiza si cambias el ConfigMap (el env del proceso es inmutable).
- **`envFrom`**: cómodo pero sin renombrar; una clave `LOG-LEVEL` con guion es un nombre de env *inválido* y el Pod no arrancará.
- **`volumeMounts`**: la app lee `/etc/app/LOG_LEVEL` como archivo. **El kubelet actualiza el contenido en vivo** cuando el ConfigMap cambia (eventualmente consistente, sync period default 60 s). Si tu app releé el archivo o escucha SIGHUP, tienes hot-reload de config sin rollout.

---

## 5. Secret: tipos y creación

Secret tiene un campo `type` que no es decorativo: distintos controllers esperan tipos distintos.

| `type` | Uso |
|--------|-----|
| `Opaque` (default) | Credenciales genéricas. |
| `kubernetes.io/dockerconfigjson` | Pull de imágenes privadas (`imagePullSecrets`). |
| `kubernetes.io/tls` | Pares `tls.crt` + `tls.key`, consumidos por Ingress/Gateway. |
| `kubernetes.io/service-account-token` | Tokens de ServiceAccount (hoy en gran parte reemplazados por projected tokens). |
| `bootstrap.kubernetes.io/token` | Join tokens de kubeadm. |

### 5.1 Creación

```bash
# Opaque desde literales
kubectl create secret generic db \
  --from-literal=username=app \
  --from-literal=password=dummy-not-real

# Opaque desde archivos (una clave por archivo)
kubectl create secret generic tls-material --from-file=ca.crt --from-file=client.crt

# dockerconfigjson
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=ci \
  --docker-password=dummy \
  --docker-email=ci@example.local

# tls
kubectl create secret tls app-tls --cert=./tls.crt --key=./tls.key
```

### 5.2 `data` vs `stringData`

Al escribir YAML:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db
type: Opaque
data:
  password: ZHVtbXk=   # base64 de "dummy"
stringData:
  username: app        # el API server lo convierte a base64 por ti
```

`stringData` es solo "quality of life": el objeto almacenado termina igual. No creas que uno es "más seguro" que el otro.

### 5.3 Consumo

```yaml
# env (riesgo de leaks, ver sección 6)
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db
        key: password

# volumen (preferido)
volumeMounts:
  - name: db-cred
    mountPath: /etc/app/secret
    readOnly: true
volumes:
  - name: db-cred
    secret:
      secretName: db
      defaultMode: 0400
```

Montado como volumen, cada clave es un archivo. `defaultMode: 0400` evita que otros procesos del Pod lo lean.

---

## 6. Riesgos de Secret como env var

El canon operativo es: **config → env; secretos → archivo**. Las razones concretas:

1. **`kubectl describe pod` imprime los nombres y el `valueFrom` del env**. No el valor, pero sí la referencia. Un `get secrets` resuelve el valor en una línea.
2. **`/proc/<pid>/environ` dentro del contenedor** es legible por cualquier proceso con mismo UID. Un segundo contenedor del Pod ve los env vars del primero si comparte UID.
3. **Logs de crash**: muchas apps (Python, Node) imprimen `os.environ` o similares en handlers de excepción no sanitizados. Un `CrashLoopBackOff` que loggea el estado completo filtra la credencial a Loki/Elasticsearch, donde ya no la controlas.
4. **Librerías de terceros** (ORMs, SDKs cloud) a veces imprimen la URL de conexión completa con la password embebida.
5. **Child processes** heredan el environment. Si tu app lanza un `sh -c` para una tarea de mantenimiento, el shell ve la DB password.
6. **Core dumps** (si están activos) capturan la memoria del proceso, incluyendo el env.

Un Secret montado como archivo evita 1–5 (el valor nunca está en el env del proceso). Mitigar 6 requiere `kernel.core_pattern` controlado o `securityContext.readOnlyRootFilesystem` + ulimit coredump=0.

---

## 7. Volúmenes básicos

Antes de `PersistentVolume`/`PersistentVolumeClaim` (que son el tema de `k8s-08`), Kubernetes trae varios volúmenes "sin estado persistente" útiles:

### 7.1 `emptyDir`

Un directorio creado al arrancar el Pod, vive mientras viva el Pod, se borra cuando el Pod muere. Útil como scratch, caches locales, o canal de intercambio entre contenedores del mismo Pod.

```yaml
volumes:
  - name: scratch
    emptyDir: {}
  - name: ramdisk
    emptyDir:
      medium: Memory   # tmpfs; respeta memory limits del Pod
      sizeLimit: 64Mi
```

### 7.2 `hostPath`

Monta un path del nodo dentro del Pod. **Casi siempre antipatrón**:

- Acopla el Pod a *ese* nodo (si lo mueves, el estado no está).
- Si el path es sensible (`/`, `/var/run/docker.sock`, `/etc`, `/proc`), un contenedor comprometido escala a root del nodo trivialmente.
- Pod Security Standards `restricted` lo prohíbe.

Casos legítimos: agents de infraestructura (DaemonSets de logs, node-exporter, CSI drivers) que *tienen* que leer archivos del host. Fuera de eso: usa `emptyDir`, `ConfigMap`, `Secret` o un PV.

### 7.3 `projected`

Agrupa varias fuentes (`secret`, `configMap`, `downwardAPI`, `serviceAccountToken`) en un solo mount. El kubelet aplica los cambios de forma **atómica** vía rename sobre el directorio: no verás un estado medio actualizado.

```yaml
volumes:
  - name: all-in-one
    projected:
      sources:
        - configMap:
            name: app-config
        - secret:
            name: db
            items:
              - key: password
                path: db-password
        - downwardAPI:
            items:
              - path: "labels"
                fieldRef:
                  fieldPath: metadata.labels
```

Útil para apps que esperan un único directorio de "material" (config + credenciales + metadatos) y para rotaciones coherentes.

### 7.4 `downwardAPI`

Expone metadatos del propio Pod (labels, annotations, nombre, namespace, IP, requests/limits) como env vars o archivos. Útil para que la app sepa dónde está corriendo (y lo loguee en structured logs).

```yaml
env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
```

---

## 8. Comportamiento del kubelet: hot-reload y proyección atómica

Cuando montas un `ConfigMap` o `Secret` como volumen, el kubelet:

1. Al arrancar el Pod, descarga el objeto del `kube-apiserver` y materializa cada clave en un archivo bajo un *symlink* a un directorio timestamped (`..YYYY_MM_DD_HH_MM_SS.ULID/`).
2. Cada ~60 s (configurable con `--sync-frequency`), re-consulta el objeto.
3. Si cambió, escribe el nuevo contenido en un **nuevo** directorio timestamped y hace un `rename(2)` del symlink `..data` para apuntar al nuevo. Los paths visibles para la app apuntan al symlink, así que ven el cambio atómicamente.

Dos consecuencias:

- Hot-reload funciona si la app relé el archivo (poll o `inotify`).
- **No** funciona si el objeto se montó por `subPath` — `subPath` rompe el mecanismo de symlinks y congela el valor inicial. Es una trampa común.

---

## 9. Encryption at rest de etcd

Para que etcd no guarde Secrets como base64 cleartext, hay que proveer un `EncryptionConfiguration` al `kube-apiserver` vía `--encryption-provider-config=/etc/kubernetes/enc.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-of-32-random-bytes>
      - identity: {}   # fallback para leer datos antiguos
```

Providers soportados:

- `identity` — sin cifrar (default implícito si no configuras nada).
- `aescbc`, `aesgcm`, `secretbox` — cifrado local con llave que el apiserver tiene en disco.
- `kms` v1 / v2 — delega al KMS del cloud (AWS KMS, GCP KMS, Vault Transit); la llave simétrica *nunca* vive en el apiserver.

**Importante**: configurar `EncryptionConfiguration` cifra Secrets *nuevos* y los que *se vuelvan a escribir*. Para cifrar los existentes:

```bash
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

Esto fuerza una reescritura y, por tanto, un re-cifrado.

Clusters managed:

- **EKS**: `--encryption-config` apunta a AWS KMS; se activa al crear el cluster y es irreversible.
- **GKE**: *Application-layer Secrets Encryption* con Cloud KMS, también por bandera al crear/actualizar.
- **AKS**: *KMS etcd encryption* con Azure Key Vault.

---

## 10. Secret managers externos (walkthrough)

Aun con encryption at rest, el Secret vive como objeto K8s: cualquier `ServiceAccount` con `get secrets` lo ve. Y el ciclo de vida (rotación, auditoría, versionado) suele vivir fuera del cluster. De ahí el patrón de **secret managers externos**:

### 10.1 External Secrets Operator (ESO)

Dos CRDs:

- `SecretStore` (o `ClusterSecretStore`): cómo autenticarse con el backend (Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, 1Password…).
- `ExternalSecret`: qué secretos pedir y cómo mapearlos a un `Secret` nativo que la app consume igual que siempre.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-sm
    kind: ClusterSecretStore
  target:
    name: db                      # el Secret nativo que materializa
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: prod/app/db
        property: password
```

Ventaja: la app no cambia (sigue leyendo un Secret montado como archivo). La rotación en AWS SM se refleja en el cluster sin despliegue.

### 10.2 Secrets Store CSI Driver

Monta secretos del backend directamente como **archivos efímeros en un volumen CSI**. No crea un Secret nativo por default (opción `syncSecret.enabled: true` lo hace si lo pides). Más estricto en el modelo mental (nunca hay Secret en etcd), más complejo en adopción.

### 10.3 Vault Agent Injector

Un `MutatingAdmissionWebhook` de HashiCorp Vault inyecta un sidecar Vault Agent al Pod (con anotaciones). El sidecar renderiza plantillas con secretos de Vault en un `emptyDir` compartido con el contenedor principal. Opcionalmente renueva leases y rota.

### 10.4 ¿Cuál elegir?

| | ESO | CSI Driver | Vault Injector |
|---|---|---|---|
| Secret nativo en etcd | Sí (sincronizado) | No (opcional) | No |
| App no cambia | Sí | Si usas syncSecret | Vía plantilla + archivo |
| Multi-backend | Sí | Sí | Solo Vault |
| Overhead | Bajo (controller) | Driver per-nodo | Sidecar per-Pod |
| Caso típico | Equipos cloud con AWS/GCP SM | Compliance estricta (no Secret nativo) | Shops ya en Vault |

Para el curso (y para la mayoría de equipos pequeños): **ESO** es el default razonable.

---

## 11. Errores comunes

- **"Puse el Secret, está seguro".** No: es base64 cleartext hasta que configures encryption at rest.
- **Secreto como env var y la app lo imprime** en el health check o en `/debug/vars`. Lo verás en Loki/Grafana a los 30 s.
- **`envFrom` con un ConfigMap que tiene una clave `foo-bar`**: `foo-bar` no es un nombre de env válido; el Pod no arranca con un error oscuro de validación.
- **Montar un Secret por `subPath`** y esperar hot-reload: no funciona. `subPath` fija el contenido inicial.
- **`hostPath` para "compartir datos entre Pods"**: antipatrón; usa un PV con access mode `RWX` (si lo necesitas de verdad) o un servicio real (DB, object store).
- **Rotar un Secret pero no reiniciar Pods que lo consumen como env var**: siguen con el valor viejo.
- **`defaultMode` demasiado permisivo (0644, 0755)**: cualquier proceso del Pod lee la credencial. Usa `0400`.
- **No activar `EncryptionConfiguration` en self-hosted** porque "el cluster está en una VPC privada". Un backup de etcd desprotegido es un leak completo.

---

## 12. Síntesis y evaluación

Al salir del módulo deberías poder responder, sin consultar:

1. ¿Qué diferencia hay entre un `ConfigMap` consumido como `envFrom` y como `volumeMounts`? Nombra una ventaja operativa de cada uno.
2. ¿Por qué `base64 ≠ encryption`? ¿Qué comando usarías para "descifrar" un Secret?
3. Enumera tres vectores concretos por los que un Secret como env var puede filtrarse.
4. ¿Qué habilita `EncryptionConfiguration` en el `kube-apiserver`, y qué *no* habilita?
5. ¿Cuál es la diferencia operativa entre ESO y Secrets Store CSI Driver?
6. ¿Por qué `hostPath` suele ser antipatrón? Da dos escenarios donde sí es legítimo.
7. ¿Cuándo elegirías `projected` sobre dos volúmenes separados?

Si fallas 3 o más, repasa las secciones correspondientes antes de pasar a `k8s-06`.
