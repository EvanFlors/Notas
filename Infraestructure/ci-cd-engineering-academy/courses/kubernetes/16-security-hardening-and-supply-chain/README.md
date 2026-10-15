# k8s-16 — Security hardening y supply chain

## Identificación

- **ID:** `k8s-16-security-hardening-and-supply-chain`
- **Curso:** `kubernetes`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `k8s-12-rbac-serviceaccounts-admission-policy`. Deseable: `dkr-13-runtime-security-and-hardening`, `dkr-14-supply-chain-sbom-signing-provenance`, `gha-14-supply-chain-sbom-attestations-signing`.

## Objetivo

Cerrar la superficie de ataque del cluster **y** de los workloads. Al terminar, debes poder tomar un cluster "default" (todo permitido, PSA no activo, imágenes sin firmar, auditoría apagada), auditar su postura y producir un plan de hardening priorizado que lleve ese cluster a un estado comparable al de un entorno productivo serio: **Pod Security Standards `restricted` por default, imágenes firmadas y verificadas en admission, runtime detection activo, auditoría y encryption at rest configuradas, RBAC mínimo**.

## Alcance

Este módulo cubre:

- **Pod Security Admission (PSA)** con el label `pod-security.kubernetes.io/enforce=restricted` por default en namespaces de app.
- **`securityContext`** por Pod y por container: `runAsNonRoot`, `runAsUser`/`runAsGroup`, `fsGroup`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, `appArmorProfile: RuntimeDefault`.
- **Runtime alternativo**: cuándo tiene sentido **gVisor** (RuntimeClass `gvisor`) o **Kata Containers** y qué garantía adicional dan.
- **Anti-patrones**: `privileged: true`, `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` volumes, montar el socket del containerd/CRI.
- **Image policy**: firmar con **cosign** (keyless u offline key) y verificar en admission con **Kyverno** `verifyImages` (y referencia a sigstore `policy-controller`).
- **Escaneo**: `trivy` en el pipeline y **Trivy Operator** dentro del cluster para VulnerabilityReports y ConfigAuditReports continuos.
- **Runtime security**: **Falco** como DaemonSet con driver eBPF, reglas built-in más una regla custom (shell-in-container).
- **Benchmarking**: **CIS Kubernetes Benchmark**, `kube-bench` como Job in-cluster, nociones de `kube-hunter`.
- **Control plane hardening** (lectura y lab controlado): encryption at rest de etcd, audit logging (`audit-policy.yaml`), anonymous auth desactivado, TLS entre componentes, `cluster-admin` solo para bootstrap.

Lo que **no** cubre (viene después o está aparte):

- Secrets managers externos (External Secrets Operator, Vault) — fue parte de `k8s-05` y `k8s-12`.
- Policy-as-code deep en Gatekeeper/Rego o CEL en `ValidatingAdmissionPolicy` — `k8s-12`.
- mTLS por service mesh — `k8s-18`.
- Backup, DR y upgrades — `k8s-17`.

## Materiales

- **`theory/lesson.md`** — lección profunda, 12 secciones. Lee de principio a fin antes de los ejemplos.
- **`examples/`**:
  - `01-securitycontext-strict/` — Pod y Deployment con el `securityContext` productivo completo. Compara con una versión "default insegura" y muestra por qué PSA `restricted` rechaza la segunda.
  - `02-cosign-verify-admission/` — Kyverno `ClusterPolicy` con `verifyImages` usando la clave pública de cosign. Incluye manifiestos de policy y un Pod de ejemplo (imagen firmada vs sin firmar).
  - `03-falco-rules/` — manifiesto del DaemonSet (resumen), una **custom rule** YAML (`shell_in_container_custom.yaml`) y cómo cargarla vía ConfigMap.
- **`activities/`**:
  - `01-harden-the-capstone/` — **guided-lab**. El estudiante toma un `Deployment` deliberadamente laxo, lo endurece y aplica PSA `restricted` al namespace. El validador comprueba el namespace, el `securityContext` y que un Pod inseguro es rechazado.
  - `02-run-kube-bench-and-fix/` — **independent**. El estudiante lanza `kube-bench` como Job, parsea la salida, elige las 3 fallas más críticas y documenta plan de remediación en `REMEDIATIONS.md`. El validador comprueba estructura.
- **`resources/links.md`** — documentación oficial, CIS, Kyverno, Falco, cosign, Trivy, PSA.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar cómo PSA aplica el label de namespace a cada Pod admitido; diferenciar `privileged` de "root común"; explicar qué garantiza cosign + verificación en admission que no garantiza un escaneo de imagen; explicar qué ve Falco a nivel syscall y por qué eBPF cambió el costo. |
| Operativa | Aplicar PSA `restricted` + `securityContext` productivo; instalar Kyverno y escribir `verifyImages` para una clave pública conocida; firmar una imagen con cosign (modo offline-key) y empujarla al registry local; interpretar un reporte de `kube-bench`; escribir y cargar una regla Falco custom. |
| Arquitectónica | Auditar un cluster "default" y producir un plan de hardening priorizado; decidir cuándo subir al runtime gVisor; decidir qué `--certificate-identity` usar en producción; justificar por qué `cluster-admin` *fuera de bootstrap* siempre es un hallazgo. |

## Criterios de evaluación

- Namespace de app con `pod-security.kubernetes.io/enforce=restricted` y Deployment pasando la admisión con el `securityContext` requerido.
- Un Pod intencionadamente laxo (sin `runAsNonRoot`, con `privileged: true`) es **rechazado** por PSA con mensaje legible.
- Kyverno `ClusterPolicy` `verify-images` instalada y rechazando un Pod cuya imagen no está firmada por la clave esperada.
- `REMEDIATIONS.md` de la Actividad 02 contiene los 3 hallazgos priorizados con mecanismo, impacto, remediación concreta y comando/manifiesto propuesto; el validador comprueba estructura.
- Auditoría escrita de un cluster "default" (ejercicio final de la lección §12) con al menos 10 hallazgos clasificados por severidad.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (1 h 45 min; es la lección más densa del nivel 4).
2. Reproduce `examples/01-securitycontext-strict/`. Aplica el Deployment seguro al namespace restricted; aplica el inseguro al mismo namespace y lee el mensaje de rechazo.
3. Reproduce `examples/02-cosign-verify-admission/`. Instala Kyverno, carga la policy, intenta aplicar un Pod con imagen sin firmar.
4. Lee `examples/03-falco-rules/` (requiere privileged DaemonSet; **puede SKIP** en entornos managed/restringidos).
5. Haz la Actividad 01. Valida.
6. Haz la Actividad 02. No consultes la solución mientras escribes el `REMEDIATIONS.md`.

## Siguiente

→ `k8s-17-cluster-lifecycle-upgrades-backup-multi-cluster`: upgrades sin dolor, Velero, DR, multi-cluster.

## Notas sobre entorno

- Requiere **kind + kubectl**. Para los ejemplos: **Kyverno** (`helm install`), **cosign** CLI. Opcional: **Trivy**, **Falco**.
- **Falco** necesita un DaemonSet privileged con acceso a `/proc` y al kernel; en entornos managed restrictivos (algunos EKS/GKE con node pools endurecidos) puede fallar: el ejemplo **marca SKIP** y describe cómo verificar manualmente.
- `kube-bench` corre en-cluster como `Job`. En kind detecta correctamente el nodo como `kubelet` y worker; el control plane dentro de kind es un contenedor y algunos checks saldrán `WARN` o `INFO` por topología.
- Todos los artefactos de ejecución viven en `/tmp/k8s-16-*/`. Cada actividad incluye limpieza explícita.
- No se usan secretos reales. La clave de cosign se genera localmente con `cosign generate-key-pair` y vive en `/tmp/`.
