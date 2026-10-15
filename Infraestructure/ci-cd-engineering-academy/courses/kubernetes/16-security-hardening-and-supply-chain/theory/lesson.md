# Lección: Security hardening y supply chain en Kubernetes

> **ID:** `k8s-16-security-hardening-and-supply-chain` · **Nivel:** producción · **Duración:** 6 h
> **Prerrequisitos:** `k8s-12` (RBAC, admission, Kyverno básico), `dkr-13` (hardening de contenedores), `dkr-14` (cosign, SBOM, attestations). Linux (namespaces, capabilities, seccomp).

---

## 1. Introducción intuitiva

Un cluster Kubernetes "default" **es inseguro**. No porque Kubernetes esté roto, sino porque los defaults optimizan para que todo funcione en una demo: `kubectl run nginx` arranca; cualquier Pod puede alcanzar a cualquier otro Pod; el UID por default suele ser `root`; el filesystem de root se puede escribir; no hay restricción sobre qué imagen se admite; `kube-apiserver` acepta tokens anónimos en algunas distribuciones; `etcd` guarda los Secret como base64 (que **no es** cifrado); el audit log suele estar apagado; y el primer `ServiceAccount` que te instala el chart de turno trae `cluster-admin` "para que no te des de topes".

Cada uno de esos defaults es una decisión razonable para empezar. **Ninguno sobrevive a producción.** El objetivo del hardening es invertir la lógica: *todo prohibido, se abre solo lo mínimo necesario*. Y como "lo mínimo" varía por carga, lo escribimos como **policy declarativa** —Pod Security Standards, Kyverno `ClusterPolicy`, NetworkPolicy— para que la regla sea el código y no la buena voluntad del operador.

Hardening de un cluster se hace en **cinco capas superpuestas**:

1. **Imagen** — qué construyes y qué firmaste (cubierto en `dkr-11`, `dkr-13`, `dkr-14`).
2. **Workload** — `securityContext` del Pod, PSA del namespace, NetworkPolicy, RBAC del ServiceAccount.
3. **Admission** — Kyverno/CEL rechazando imágenes sin firmar, labels faltantes, patrones peligrosos.
4. **Runtime** — Falco en cada nodo observando syscalls; opcionalmente runtimes aislados (gVisor, Kata).
5. **Control plane** — encryption at rest de etcd, audit log, TLS entre componentes, `--anonymous-auth=false`, RBAC mínimo.

Esta lección cubre las capas 2 a 5 asumiendo que la 1 ya la hiciste en el curso de Docker. Fallar en una se mitiga con las otras. Eso es **defensa en profundidad**: un atacante que compromete una dependencia npm (capa 1) todavía tiene que escapar un `securityContext` restricted (2), ser admitido por un cluster que exige firma (3), y pasar inadvertido ante Falco (4), antes de siquiera tocar el control plane (5).

La métrica honesta de madurez: *¿Cuántas de las cinco capas te defienden ahora mismo contra un atacante que ya controla un Pod?* Un cluster "default" típicamente te defiende en **cero**. Un cluster hardened razonable te defiende en **cuatro**. La quinta es siempre el eslabón más caro: encryption at rest + audit log maduros + rotación de certificados sin dolor requieren plataforma, no un `helm install`.

---

## 2. Fundamentos: ¿qué protege a un contenedor en K8s?

Las mismas primitivas de Linux que viste en `dkr-10` y `dkr-13`:

- **Namespaces** (pid, mnt, net, uts, ipc, user, cgroup) — aislamiento de visibilidad.
- **cgroups v2** — límites de CPU, memoria, pids, io.
- **Capabilities** — subdivisión de los poderes de root (CAP_NET_BIND_SERVICE, CAP_SYS_ADMIN, …).
- **seccomp** — filtro de syscalls permitidos.
- **AppArmor / SELinux (MAC)** — políticas obligatorias que el kernel aplica aunque el proceso sea root.

Kubernetes **no inventa seguridad de contenedores**. Define una API declarativa (`securityContext`) y un admission controller (**Pod Security Admission**) para que esas primitivas se apliquen de forma consistente y auditable a cada Pod del cluster. Si entiendes `dkr-13`, lo que sigue es traducción YAML.

Donde K8s **sí** añade capas propias:

- **ServiceAccount tokens**: todo Pod recibe un token JWT para hablar con el apiserver. Si no restringes, ese token puede listar Secrets.
- **NetworkPolicy**: aislamiento de red *dentro* del cluster. Sin NetworkPolicy, cualquier Pod llega a cualquier otro Pod.
- **Admission controllers**: puerta final antes de que un objeto se persista en etcd. Es *el* lugar correcto para "esta imagen debe estar firmada", "este namespace no admite root", "este Pod requiere `priorityClassName`".
- **Audit log**: todas las requests al apiserver quedan registradas (si lo activas).
- **Encryption at rest**: etcd puede cifrar los valores de los Secret con KMS/AES-GCM (si lo configuras; **no** es default).

---

## 3. Pod Security Standards y Pod Security Admission

### 3.1 Historia breve

- **PodSecurityPolicy (PSP)**: controlador original, en-cluster, difícil de operar (el admission requería que el SA del Pod tuviera permiso de *usar* la PSP). Deprecado en 1.21, eliminado en 1.25.
- **Pod Security Admission (PSA)**: reemplazo integrado en el apiserver desde 1.23, GA en 1.25. **No requiere CRDs, no requiere RBAC extra, no requiere Helm**. Se configura con *labels en el namespace*.

### 3.2 Los tres niveles

PSA define tres perfiles tipados (los "Pod Security Standards"):

| Nivel | Qué permite | Caso |
|-------|-------------|------|
| `privileged` | Todo. Sin restricción. | DaemonSets de sistema (Falco, CNI), confianza explícita. |
| `baseline` | Sin `privileged`, sin `hostNetwork/PID/IPC`, sin `hostPath`, capabilities limitadas. Permite `runAsUser: 0`. | Workloads legacy que no se pueden tocar aún. |
| `restricted` | `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, volúmenes acotados, `readOnlyRootFilesystem` recomendado. | **Default productivo**. |

### 3.3 Tres modos de aplicación

Por cada nivel se pueden activar hasta tres modos en el namespace, cada uno con su label:

- `pod-security.kubernetes.io/enforce=<nivel>` → **rechaza** la admisión si el Pod viola el nivel.
- `pod-security.kubernetes.io/audit=<nivel>` → **registra** en audit log sin rechazar.
- `pod-security.kubernetes.io/warn=<nivel>` → **avisa** al usuario que aplicó el manifiesto (kubectl warning), sin rechazar.

Opcionalmente, `enforce-version`, `audit-version`, `warn-version` permiten pinear la versión de la especificación PSS (por default la de la versión del cluster).

### 3.4 Cómo se aplica internamente

PSA es un **admission plugin built-in** en `kube-apiserver`. En cada request de creación o actualización de Pod (o de controladores que crean Pods: Deployment, StatefulSet, Job), PSA:

1. Lee los labels del namespace del Pod.
2. Compara el PodSpec contra la especificación del nivel.
3. Si está en `enforce` y viola → rechaza con un mensaje que lista exactamente qué campos están mal.
4. Si está en `warn` → añade un warning HTTP a la respuesta (kubectl lo imprime en amarillo).
5. Si está en `audit` → emite un evento al audit log con la anotación correspondiente.

Importante: PSA **no muta** nada. Si el Pod viola, falla. Si no quieres que falle, agrega el `securityContext` tú mismo o usa un *mutating webhook* (Kyverno `mutate`) que lo complete.

### 3.5 Patrón productivo

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Default en el cluster: todos los namespaces de aplicación `restricted`. Namespaces de sistema (`kube-system`, `falco`, `kyverno`, `trivy-system`) pueden quedar en `privileged` si lo justificas.

Un atajo útil: aplicar la configuración por default en el apiserver con un `AdmissionConfiguration` + `PodSecurityConfiguration` (archivo que lee el apiserver al arrancar). Así cualquier namespace nuevo nace restricted sin necesidad de ponerle labels.

---

## 4. `securityContext` que pasa `restricted`

El contrato explícito. Este es el PodSpec mínimo que admite PSA `restricted`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector: { matchLabels: { app: web } }
  template:
    metadata:
      labels: { app: web }
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: web
          image: ghcr.io/example/web@sha256:abc...     # digest pinned
          imagePullPolicy: IfNotPresent
          ports: [{ containerPort: 8080 }]
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 10001
            capabilities:
              drop: ["ALL"]
          resources:
            requests: { cpu: "50m", memory: "64Mi" }
            limits:   { cpu: "500m", memory: "256Mi" }
          volumeMounts:
            - { name: tmp, mountPath: /tmp }
            - { name: cache, mountPath: /var/cache/app }
      volumes:
        - { name: tmp, emptyDir: {} }
        - { name: cache, emptyDir: {} }
```

Puntos clave:

- `runAsNonRoot: true` tanto a nivel Pod como container (redundancia intencional).
- `readOnlyRootFilesystem: true` fuerza que la app escriba sólo en volúmenes montados (`emptyDir` para `/tmp` y cache; `PersistentVolume` para datos reales).
- `capabilities.drop: [ALL]` y **no** `add:` — si realmente necesitas `NET_BIND_SERVICE`, es *un* add, no "ALL dropped except…".
- `seccompProfile: RuntimeDefault` carga el perfil que trae el runtime (containerd/CRI-O); si tu kernel lo soporta y usas kind reciente, basta con esto.
- `allowPrivilegeEscalation: false` cierra la vía setuid/setgid.
- `automountServiceAccountToken: false` evita montar el token JWT si el Pod no habla con el apiserver.
- `image` por **digest**, no por tag — la firma de cosign se verifica sobre el digest.

### 4.1 Qué pasa cuando algo falta

Aplicar un `Pod` así en un namespace `restricted` falla con un mensaje tipo:

```
Error from server (Forbidden): error when creating "bad-pod.yaml": pods "bad" is forbidden: violates PodSecurity "restricted:latest":
  allowPrivilegeEscalation != false (container "web" must set securityContext.allowPrivilegeEscalation=false),
  unrestricted capabilities (container "web" must set securityContext.capabilities.drop=["ALL"]),
  runAsNonRoot != true (pod or container "web" must set securityContext.runAsNonRoot=true),
  seccompProfile (pod or container "web" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

Ese mensaje es tu documentación. Léelo.

---

## 5. seccomp, AppArmor y runtimes aislados

### 5.1 seccomp

`RuntimeDefault` carga el perfil que trae el container runtime (containerd lo envía al kernel al crear el contenedor). Para la mayoría de workloads web es suficiente y bloquea decenas de syscalls peligrosos (`kexec_load`, `init_module`, `mount` fuera de namespaces, `ptrace` cruzado, etc.).

Si necesitas más control, un perfil **Localhost** se guarda en `/var/lib/kubelet/seccomp/profiles/<name>.json` en cada nodo (gestionarlo ya es trabajo de plataforma: DaemonSet que lo copia, o Security Profiles Operator).

### 5.2 AppArmor

Desde K8s 1.30, AppArmor se declara nativamente en `securityContext.appArmorProfile`:

```yaml
securityContext:
  appArmorProfile:
    type: RuntimeDefault     # o Localhost / Unconfined
```

(Antes de 1.30 se hacía con anotaciones `container.apparmor.security.beta.kubernetes.io/<container>: runtime/default`.) Solo aplica en nodos con AppArmor habilitado (Ubuntu/Debian). En RHEL/Fedora la MAC es SELinux y se configura con `seLinuxOptions`.

### 5.3 gVisor y Kata

Cuando un workload es *particularmente* desconfiable (ejecutas código de usuario arbitrario, por ejemplo CI/sandbox, notebooks de datos), un `securityContext` strict **sigue compartiendo kernel con el host**. Un 0-day del kernel = escape.

Dos respuestas:

- **gVisor** (`runsc`): sandbox en user-space que reimplementa la mayor parte del ABI de Linux. Cada syscall del container pasa por `runsc`; el kernel real ve muchísimo menos. Overhead medible, no catastrófico.
- **Kata Containers**: ejecuta el Pod dentro de una **microVM** (QEMU + kernel propio). Aislamiento equivalente a VM, con footprint de contenedor. Overhead mayor; soporte depende del nodo.

En K8s se seleccionan vía `RuntimeClass`:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata: { name: gvisor }
handler: runsc
---
apiVersion: v1
kind: Pod
metadata: { name: untrusted }
spec:
  runtimeClassName: gvisor
  containers: [...]
```

Decisión: **gVisor** para cargas semi-desconfiadas con tolerancia a overhead moderado; **Kata** si necesitas garantía tipo VM; el runtime default (containerd) para el 99% del cluster.

---

## 6. Anti-patrones que PSA `restricted` prohíbe

| Patrón | Por qué es peligroso | Alternativa |
|--------|----------------------|-------------|
| `privileged: true` | Equivale a *root en el host*: todas las capabilities, sin seccomp, sin AppArmor. | Nunca en workloads de app. Para DaemonSets de sistema (Falco, CNI, storage), namespace aparte en `privileged`. |
| `hostNetwork: true` | El Pod comparte el network namespace del nodo; puede escuchar en puertos del host, ver el tráfico. | Service + Ingress. Solo para componentes de infra (kube-proxy, CNI). |
| `hostPID: true`, `hostIPC: true` | Ver y señalar procesos del host. | Nunca en apps. |
| `hostPath` volume | Montar un directorio del nodo (p. ej. `/`, `/var/run/docker.sock`, `/var/lib/kubelet`). | `emptyDir`, `PersistentVolume`, `configMap`, `secret`. Para agentes de sistema que *requieren* hostPath, namespace privileged y RBAC acotado. |
| Montar `/var/run/containerd/containerd.sock` o `docker.sock` | Equivalente a root en el host (puede crear contenedores privileged en el nodo). | Nunca sin justificación extraordinaria y revisión de seguridad. |
| `runAsUser: 0` sin más | Cualquier bug remoto escala a root dentro del contenedor; combinado con un hostPath, root en el host. | `runAsNonRoot: true` + UID numérico >=1000. |
| `allowPrivilegeEscalation: true` (default) | `setuid`/`setgid` pueden elevar el UID después de arrancar. | `allowPrivilegeEscalation: false`. |
| `capabilities: add: [SYS_ADMIN]` | SYS_ADMIN es "casi todo"; equivalente moral a `privileged`. | `drop: [ALL]` y añadir sólo la capability específica (p. ej. `NET_BIND_SERVICE`). |

PSA `restricted` rechaza **todos** los anteriores en el nivel enforce. Esa es la gracia: no es una checklist que el operador recuerde, es el apiserver quien se niega.

---

## 7. Image policy: cosign + verify en admission

### 7.1 El modelo

La cadena completa de supply chain (vista a fondo en `dkr-14` y `gha-14`):

```
Dockerfile → build → scan (Trivy) → sign (cosign) → push (registry) → verify (admission) → run
```

Hasta `dkr-14`/`gha-14` llegamos a *firmar* la imagen y publicar la firma como artefacto OCI relacionado al digest. En K8s, **la verificación es obligatoria en admission**: un Pod cuya imagen no esté firmada por una identidad que tú autorizas **no debe ser admitido**.

### 7.2 Dos herramientas

- **sigstore `policy-controller`**: proyecto oficial de sigstore. CRD `ClusterImagePolicy`.
- **Kyverno** `verifyImages`: regla dentro de un `ClusterPolicy` normal. Más simple si Kyverno ya está instalado por otros motivos (y lo está, porque lo usas también para "no root", "requiere labels", etc.).

Esta lección usa **Kyverno** (el ejemplo 02 lo despliega y lo demuestra).

### 7.3 Modos de identidad

- **Keyless (OIDC)**: cosign firma con un certificado efímero emitido por **Fulcio** a partir de una identidad OIDC (GitHub Actions, Google, etc.) y publica una entrada en **Rekor** (transparency log). En admission verificas identidad del subject (`certificate-identity-regexp`) e issuer (`certificate-oidc-issuer`). Es el modo productivo si firmas desde CI.
- **Key pair offline**: `cosign generate-key-pair` produce `cosign.key` + `cosign.pub`. Útil para dev, para registries air-gapped, y para labs. En K8s cargas la `cosign.pub` dentro de la policy (`attestors.entries[].keys.publicKeys`).

### 7.4 Kyverno `verifyImages` (modo offline-key)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images-cosign
spec:
  validationFailureAction: Enforce   # Audit en etapa de rollout
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signed-images
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [app]
      verifyImages:
        - imageReferences:
            - "localhost:5000/app/*"
          mutateDigest: true
          verifyDigest: true
          required: true
          attestors:
            - entries:
                - keys:
                    publicKeys: |
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                      -----END PUBLIC KEY-----
                    rekor:
                      ignoreTlog: true   # modo offline, sin Rekor
```

Lo que esto hace al admitir un Pod:

1. Para cada container cuya imagen matchee `localhost:5000/app/*`.
2. Kyverno descarga la firma del registry (OCI 1.1 referrers o legacy tag `.sig`).
3. Valida la firma contra la clave pública embebida.
4. Si `mutateDigest: true`, reemplaza la referencia por `@sha256:<digest>` (pin inmutable).
5. Si cualquier container matchea y no verifica → **rechaza el Pod** con razón legible.

### 7.5 Keyless (producción)

```yaml
attestors:
  - entries:
      - keyless:
          subject: "https://github.com/myorg/myrepo/.github/workflows/release.yml@refs/tags/v*"
          issuer: "https://token.actions.githubusercontent.com"
          rekor:
            url: https://rekor.sigstore.dev
```

Aquí el gate es: "la firma debe venir de **un workflow específico de GitHub Actions**, firmando sobre un tag `v*`". Un atacante que robe credenciales de GHA pero no pueda disparar ese workflow específico no puede producir una firma válida.

### 7.6 Lo que esto cierra y lo que no cierra

Cierra:

- **Integridad**: el bit del digest firmado es el que corre.
- **Procedencia**: lo construyó quién dices (keyless) o lo firmó una clave que controlas (offline).

No cierra:

- **Vulnerabilidades del contenido**: una imagen con `CVE-2024-XXXX` crítica puede estar firmada. Para eso: `trivy` en el pipeline y Trivy Operator en el cluster.
- **Behavior del container en runtime**: una imagen firmada puede incluir código malicioso que sólo se activa en producción. Para eso: Falco (runtime detection).

---

## 8. Trivy en pipeline y en cluster

Dos pasadas, una preventiva y una continua:

### 8.1 En pipeline (preventiva, gate de release)

Ya cubierto en `dkr-14` y `gha-14`:

```bash
trivy image --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed \
  localhost:5000/app/web:v1.2.3
```

Falla el build si hay vulnerabilidades críticas/altas con fix disponible. Importante: **ignore-unfixed** evita castigar al equipo por CVEs sin parche aguas arriba.

### 8.2 En cluster (continua, con **Trivy Operator**)

El Trivy Operator (Aqua Security) escanea periódicamente **todas las imágenes en uso en el cluster** y publica resultados como CRs:

- `VulnerabilityReport` — CVEs por container.
- `ConfigAuditReport` — mala configuración (p. ej. `runAsRoot: true`).
- `ExposedSecretReport` — secretos filtrados en capas.
- `RbacAssessmentReport` — RBAC excesivo (`cluster-admin` para apps).

Patrón: lo instalas una vez por Helm, y conectas los reportes a tu stack de alertas (Prometheus escrapea `trivy-operator-metrics` → Alertmanager). Así descubres el día que una base image que llevabas en producción desde hace meses amanece con una CVE crítica recién publicada.

Instalación mínima:

```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  -n trivy-system --create-namespace \
  --set="trivy.ignoreUnfixed=true" \
  --set="serviceMonitor.enabled=true"
```

Querys útiles:

```bash
kubectl get vulnerabilityreports -A -o json | jq '.items[] | select(.report.summary.criticalCount>0) | {ns:.metadata.namespace, name:.metadata.name, crit:.report.summary.criticalCount}'
```

---

## 9. Runtime security con Falco

### 9.1 Qué hace

**Falco** es un agente que corre como DaemonSet en cada nodo. Observa syscalls del kernel y emite alertas cuando se dispara una **regla**. "Shell abierto dentro de un contenedor" o "escritura a `/etc/passwd` desde un container" son dos reglas built-in.

Driver histórico: módulo del kernel. Driver moderno (recomendado): **eBPF** (sin cargar kernel modules, menor fricción con proveedores managed). El driver moderno sigue requiriendo privileges elevados (`CAP_BPF`, `CAP_SYS_RESOURCE`, acceso a `/proc`), por eso el DaemonSet se despliega en un namespace `privileged`.

### 9.2 Lo que una regla ve

Falco opera a nivel syscall: `execve`, `open`, `connect`, `setuid`, `openat`, `mount`, etc. Correlaciona syscalls con el container que las originó (vía cgroup) y la imagen que corre. Tipos de regla:

- *Macros*: condiciones reutilizables (`container`, `open_write`).
- *Lists*: literales (`shell_binaries = [bash, sh, zsh, ash]`).
- *Rules*: `condition` (filtro) + `output` + `priority`.

### 9.3 Ejemplo de regla custom

```yaml
- rule: Shell spawned in production container
  desc: Detect shell execution inside containers of the 'app' namespace
  condition: >
    spawned_process and container and shell_procs and
    k8s.ns.name in (app) and
    not proc.pname in (sh, bash)
  output: >
    Shell spawned in prod container
    (user=%user.name container=%container.id image=%container.image.repository
    cmd=%proc.cmdline pod=%k8s.pod.name ns=%k8s.ns.name)
  priority: WARNING
  tags: [k8s, shell, custom]
```

### 9.4 Cómo integrarlo

Falco emite a stdout por default. En producción se conecta a:

- **falcosidekick** (sidecar) que reenvía a Slack, PagerDuty, Loki, Elasticsearch, OpenSearch, S3, etc.
- **falcosidekick-ui** para visualizar.
- **Prometheus**: Falco expone métricas; falcosidekick también.

Advertencia operacional: Falco **genera ruido** en los primeros días. La curva es: desplegar en `WARNING+`, triar durante una o dos semanas, apagar o afinar las reglas que generan falsos positivos (típico: Prometheus hace `connect` a muchísimos pods; algunas reglas de "unexpected connection" lo detectan y gritan).

### 9.5 Cuándo SKIP

En entornos **managed estrictos** (algunos clusters EKS/GKE con node pools endurecidos o políticas corporativas que prohíben pods privileged), Falco puede no desplegarse. Alternativas: usar la detección nativa del proveedor (GKE Workload Identity + Security Health Analytics, EKS add-on `aws-guardduty-agent`) o migrar al modo `userspace` (sin kernel probe) con menos cobertura. En el ejemplo 03 dejamos el DaemonSet opcional y el validador reporta `SKIP` si no corre.

---

## 10. CIS Kubernetes Benchmark y auditoría del control plane

### 10.1 CIS Benchmark

El CIS (Center for Internet Security) publica benchmarks por versión de K8s: una lista de ~150 controles con *level 1* (debe hacerse) y *level 2* (debería). Secciones típicas:

1. **Control plane components** (etcd, apiserver, scheduler, controller-manager, kubelet). Flags y permisos de archivo.
2. **etcd**: `--auto-tls=false`, `--peer-auto-tls=false`, `--data-dir` propietario correcto.
3. **Control plane configuration**: `--anonymous-auth=false`, `--authorization-mode=RBAC,Node`, `--audit-log-path`, `--encryption-provider-config`.
4. **Worker nodes** (kubelet config, bootstrap, cert rotation).
5. **Policies**: PSA aplicado, NetworkPolicy default-deny, RBAC least privilege, imágenes de registries confiables, Secrets no en env vars.

### 10.2 `kube-bench`

Aqua Security publica `kube-bench`, implementación ejecutable del CIS Benchmark. Corre como binario o como `Job` en el cluster.

Un Job típico (resumido):

```yaml
apiVersion: batch/v1
kind: Job
metadata: { name: kube-bench-master, namespace: default }
spec:
  template:
    spec:
      hostPID: true                       # necesario para ver procesos del nodo
      nodeSelector: { kubernetes.io/hostname: <control-plane-node> }
      tolerations: [{ key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule }]
      containers:
        - name: kube-bench
          image: aquasec/kube-bench:latest
          command: ["kube-bench", "run", "--targets=master", "--json"]
          volumeMounts:
            - { name: var-lib-etcd, mountPath: /var/lib/etcd, readOnly: true }
            - { name: var-lib-kubelet, mountPath: /var/lib/kubelet, readOnly: true }
            - { name: etc-kubernetes, mountPath: /etc/kubernetes, readOnly: true }
      restartPolicy: Never
      volumes:
        - { name: var-lib-etcd, hostPath: { path: /var/lib/etcd } }
        - { name: var-lib-kubelet, hostPath: { path: /var/lib/kubelet } }
        - { name: etc-kubernetes, hostPath: { path: /etc/kubernetes } }
```

Salida: lista de controles `PASS/FAIL/WARN/INFO` con remediación textual.

### 10.3 `kube-hunter`

Complementario: `kube-hunter` *escanea activamente* el cluster buscando superficies expuestas (API server abierto, metrics endpoints sin auth, kubelet readonly port, dashboard expuesto). Útil para una pasada rápida después de ganar visibilidad del cluster desde la red.

### 10.4 Encryption at rest de etcd

Default: los `Secret` se guardan en etcd como base64 (en claro para fines prácticos). Fix: configurar `EncryptionConfiguration` en el apiserver:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: [secrets]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64 32-byte key>
      - identity: {}
```

Y arrancar `kube-apiserver` con `--encryption-provider-config=/etc/kubernetes/encryption.yaml`. En producción usa un KMS externo (AWS KMS, GCP KMS, Vault) vía el provider `kms`.

### 10.5 Audit logging

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources: [{ group: "", resources: ["endpoints", "services"] }]
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
```

Flags: `--audit-policy-file=...`, `--audit-log-path=/var/log/k8s-audit.log`, `--audit-log-maxage=30`, `--audit-log-maxbackup=10`, `--audit-log-maxsize=100`.

### 10.6 Flags "no-brainer"

- `--anonymous-auth=false` (apiserver y kubelet).
- `--authorization-mode=Node,RBAC` (nunca `AlwaysAllow`).
- `--profiling=false` en apiserver, controller-manager, scheduler.
- `--kubelet-client-certificate` / `--kubelet-client-key` para que el apiserver se autentique al kubelet.
- `--service-account-lookup=true`, `--service-account-signing-key-file`.
- TLS 1.2+ para todos los componentes.

En clusters managed casi todo esto viene configurado; verifícalo con `kube-bench` y lee los `WARN`.

---

## 11. RBAC: evitar `cluster-admin` fuera de bootstrap

Repaso de `k8s-12`:

- `cluster-admin` es un ClusterRole que tiene `*` sobre `*`. Un Pod cuyo ServiceAccount tenga ese binding puede **crear ClusterRoleBindings, leer Secrets de todos los namespaces, instalar DaemonSets privileged**. Es el equivalente moral a root en el cluster.
- Nunca en workloads. Si un operador *necesita* amplios permisos, se los das vía ClusterRole acotado por `resources`/`verbs`/`resourceNames`, no vía `cluster-admin`.
- Patrón: cada workload tiene su `ServiceAccount`; cada ServiceAccount tiene su `RoleBinding` namespaced con un `Role` que lista exactamente los verbs sobre los resources que usa. Si no habla con la API, `automountServiceAccountToken: false`.

Auditar RBAC excesivo:

```bash
# Listar todos los subjects con cluster-admin
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects}'

# Listar bindings "demasiado anchos"
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name | test("admin|edit"))'
```

Herramientas: `rbac-lookup`, `rbac-tool who-can get secret -A`, Trivy Operator `RbacAssessmentReport`.

---

## 12. Síntesis operativa: auditar un cluster "default"

Plantilla de auditoría (es también el ejercicio de evaluación):

| # | Área | Chequeo | Comando / evidencia | Severidad |
|---|------|---------|---------------------|-----------|
| 1 | PSA | ¿Namespaces de app tienen `enforce=restricted`? | `kubectl get ns -L pod-security.kubernetes.io/enforce` | **ALTA** si falta |
| 2 | securityContext | ¿Deployments corren como no-root y con `drop: [ALL]`? | `kubectl get deploy -A -o json \| jq ...` | **ALTA** |
| 3 | Admission | ¿Hay policy que exija firma de imagen? | `kubectl get clusterpolicies` | **ALTA** |
| 4 | Imágenes | ¿Imágenes se referencian por digest? | `kubectl get pods -A -o jsonpath='{..image}' \| tr ' ' '\n' \| grep -v '@sha256:'` | **MEDIA** |
| 5 | NetworkPolicy | ¿Hay default-deny en los namespaces de app? | `kubectl get netpol -A` | **ALTA** |
| 6 | RBAC | ¿Hay subjects con `cluster-admin`? | ver §11 | **ALTA** |
| 7 | ServiceAccount tokens | ¿`automountServiceAccountToken: false` donde no se usa? | `kubectl get pods -A -o json \| jq ...` | **MEDIA** |
| 8 | Secrets | ¿Encryption at rest configurado? | `kubectl get --raw /healthz/etcd` + flags del apiserver | **ALTA** |
| 9 | Audit log | ¿`--audit-log-path` configurado? | leer el manifest de kube-apiserver | **MEDIA** |
| 10 | Anonymous auth | ¿`--anonymous-auth=false`? | kubelet config + apiserver flags | **ALTA** |
| 11 | kube-bench | Correrlo y clasificar FAIL por severidad | ver §10.2 | — |
| 12 | Runtime | ¿Falco o equivalente desplegado? | `kubectl get ds -n falco` | **MEDIA** |
| 13 | Vulnerabilidades | ¿Trivy Operator reporta críticos sin fix tracking? | `kubectl get vulnerabilityreports -A` | **ALTA** si críticos |
| 14 | hostPath / hostNetwork | ¿Algún Pod los usa fuera de kube-system? | `kubectl get pods -A -o json \| jq ...` | **ALTA** |

Plan de hardening priorizado (orden sugerido, de mayor retorno/esfuerzo a menor):

1. **PSA `restricted` en namespaces de app** + fix de `securityContext` del capstone. (1-2 días, enorme reducción de superficie.)
2. **NetworkPolicy default-deny** por namespace + reglas explícitas. (Cubierto en `k8s-07`.)
3. **RBAC least privilege**: remover `cluster-admin` de workloads, auditar bindings.
4. **Kyverno verifyImages** apuntando a tu identidad de firma + imágenes por digest.
5. **Trivy Operator** instalado y conectado al stack de alertas.
6. **Audit log** encendido con policy razonable + rotación.
7. **Encryption at rest** de etcd (KMS si managed, aes-gcm si self-hosted).
8. **Falco** DaemonSet con reglas built-in + 2-3 custom del dominio.
9. **gVisor** para RuntimeClass "untrusted" si tienes multi-tenant real.
10. **CIS kube-bench** mensual, resolver FAILs restantes.

Entregables para considerar el módulo cerrado:

- Namespace `app` con label `enforce=restricted` y `Deployment` admitido con el `securityContext` del §4.
- Pod intencionalmente laxo (`privileged: true`) **rechazado** por PSA, mensaje de error archivado como evidencia.
- `ClusterPolicy` Kyverno `verify-images-cosign` rechazando un Pod con imagen sin firmar.
- `REMEDIATIONS.md` priorizado con los top-3 FAIL de `kube-bench` y plan concreto.
- (Opcional pero recomendado) Falco DaemonSet corriendo + log de alerta disparada por `kubectl exec` en un Pod del namespace `app`.

Esto es la base. En `k8s-17` lo complementamos con backup/restore y upgrades sin dolor; en `k8s-18` con la plataforma completa (GitOps, mesh, cost).
