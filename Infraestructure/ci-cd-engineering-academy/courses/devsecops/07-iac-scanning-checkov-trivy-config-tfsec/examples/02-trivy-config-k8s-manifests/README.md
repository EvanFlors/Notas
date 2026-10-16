# Ejemplo 02 — `trivy config` sobre manifests Kubernetes

> Lectura y análisis. Objetivo: ver `trivy config` corriendo sobre YAML de K8s y entender cómo cubre un espacio distinto a Checkov (aunque hay solape).

## 1. Manifest de ejemplo

```yaml
# bad-pod.yaml — misconfigs K8s clásicos
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
    - name: app
      image: nginx:latest           # tag :latest (CVE drift)
      securityContext:
        privileged: true            # KSV017 / AVD-KSV-0017
        runAsUser: 0                # KSV014
        allowPrivilegeEscalation: true  # KSV001
      # sin resources.limits → desalojable, pero puede DoS al nodo
      # sin resources.requests → scheduler ciego
```

## 2. Ejecutar

```bash
# Instalar Trivy una vez (brew/apt/binary) — ver links.md
trivy config bad-pod.yaml
# o toda la carpeta:
trivy config k8s/
# severidad:
trivy config --severity HIGH,CRITICAL k8s/
```

## 3. Salida (abreviada)

```
bad-pod.yaml (kubernetes)

Tests: 25 (SUCCESSES: 20, FAILURES: 5, EXCEPTIONS: 0)
Failures: 5 (HIGH: 3, CRITICAL: 2)

HIGH: Container 'app' of Pod 'bad-pod' should not be run as privileged
═════════════════════════════════════════════════════════════════════
AVD-KSV-0017 — https://avd.aquasec.com/misconfig/ksv017

CRITICAL: Container 'app' of Pod 'bad-pod' should not be run as root
════════════════════════════════════════════════════════════════════
AVD-KSV-0014 — https://avd.aquasec.com/misconfig/ksv014

HIGH: Container 'app' of Pod 'bad-pod' should not allow privilege escalation
═════════════════════════════════════════════════════════════════════════════
AVD-KSV-0001
```

## 4. Qué leer

- **AVD-KSV-NNNN**: el ID estable (Aqua Vulnerability Database — K8s Security Verification).
- **Container / Pod**: ubicación lógica.
- **Enlace `avd.aquasec.com`**: siempre leer antes de suprimir.

## 5. Supresión

Trivy config no tiene supresión in-line YAML (K8s no permite comentarios en todos los campos). Se suprime con `.trivyignore`:

```
# .trivyignore
AVD-KSV-0014  # pod corre como root temporalmente, ticket SEC-123, expires 2026-06-01
```

Para supresiones más complejas (por recurso), usa un **Rego policy** `--config-policy`.

## 6. Comparación con Checkov sobre el mismo manifest

Ejecutar también:

```bash
checkov -f bad-pod.yaml --framework kubernetes
```

Los IDs serán `CKV_K8S_*`. Habrá **solape** (ambos detectan `privileged: true`, `runAsRoot`, etc.) pero cada uno tiene reglas que el otro no. **Dos opiniones cruzadas** reducen el riesgo de false negative.

## 7. Qué entrena este ejemplo

- Correr `trivy config` sobre manifests K8s.
- Leer su salida y entender los IDs `AVD-KSV-*`.
- Entender por qué un pipeline realista corre **Checkov + Trivy config** y no uno solo.

## 8. Siguiente paso

- Ver `../03-checkov-on-plan-json/` para HCL vs plan JSON.
