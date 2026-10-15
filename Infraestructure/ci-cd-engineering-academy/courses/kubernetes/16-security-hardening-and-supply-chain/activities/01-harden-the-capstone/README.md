# Actividad 01 — Endurecer el capstone con PSA `restricted`

## 1. Identificación

- **ID:** `k8s-16-01-harden-the-capstone`
- **Tecnología:** `kubernetes`
- **Módulo:** `16-security-hardening-and-supply-chain`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Te damos un `namespace` sin labels PSA y un `Deployment` deliberadamente laxo (corre como root, filesystem escribible, `privileged: true`, sin seccomp). El validador espera que:

1. El namespace `app` tenga `pod-security.kubernetes.io/enforce=restricted`.
2. El Deployment `web` cumpla el `securityContext` productivo completo y sus Pods estén `Ready`.
3. Un Pod intencionalmente laxo (`pod-bad.yaml`) sea **rechazado** por PSA cuando lo apliques (prueba negativa).

El validador no te dice *cómo* arreglarlo. Está en `theory/lesson.md` §4 y `examples/01`.

## 3. Objetivos

- Namespace `app` con label `enforce=restricted`.
- Deployment `web` admitido, 2 réplicas Running, con:
  - `runAsNonRoot: true` (Pod y container).
  - `runAsUser` numérico ≥ 1000.
  - `allowPrivilegeEscalation: false`.
  - `readOnlyRootFilesystem: true`.
  - `capabilities.drop: [ALL]`.
  - `seccompProfile.type: RuntimeDefault`.
  - `automountServiceAccountToken: false`.
- Al intentar aplicar `pod-bad.yaml`, el apiserver lo **rechaza**.

## 4. Prerrequisitos

- `kind` + `kubectl` instalados.
- Un cluster activo. Si no tienes, `kind create cluster --name k8s-16-01` (el validador no asume nombre).
- No requiere red externa fuera del pull inicial de la base image. **Costo:** $0.

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/kubernetes/16-security-hardening-and-supply-chain/activities/01-harden-the-capstone/starter/bootstrap.sh /tmp/k8s-16-01
cd /tmp/k8s-16-01/work
```

Esto crea `/tmp/k8s-16-01/work/` con:

- `namespace.yaml` — namespace `app` **sin** labels PSA. Edítalo.
- `deploy.yaml` — Deployment laxo. Reescríbelo.
- `pod-bad.yaml` — Pod inseguro (ya listo). **No lo modifiques** — es la prueba negativa.

### 5.2 Trabajo

1. Edita `namespace.yaml` para añadir los tres labels PSA = `restricted`.
2. Reescribe `deploy.yaml`:
   - Pon `nginxinc/nginx-unprivileged:1.27-alpine` como imagen (escucha en 8080 por default y corre como UID 101; nosotros forzamos 10001).
   - Agrega `securityContext` de Pod y de container con todos los campos listados en §3.
   - Monta `emptyDir` en `/tmp`, `/var/run`, `/var/cache/nginx` (nginx los necesita escribibles).
   - `automountServiceAccountToken: false`.
   - `resources.requests/limits` razonables.
3. Aplica:
   ```bash
   kubectl apply -f namespace.yaml
   kubectl apply -f deploy.yaml
   kubectl -n app rollout status deploy/web --timeout=120s
   ```
4. Prueba negativa:
   ```bash
   kubectl apply -f pod-bad.yaml
   # Debe fallar con mensaje "violates PodSecurity restricted:..."
   ```
   El validador *espera* que falle; el bootstrap no lo aplica por ti.

### 5.3 Validar

```bash
bash courses/kubernetes/16-security-hardening-and-supply-chain/activities/01-harden-the-capstone/tests/validate.sh
```

Debe terminar con `RESULT: 7/7 controles OK`.

## 6. Resultado esperado

- `kubectl get ns app -L pod-security.kubernetes.io/enforce` muestra `restricted`.
- `kubectl -n app get pods` → 2 Pods Running y Ready.
- `kubectl apply -f pod-bad.yaml` → `Error from server (Forbidden): ... violates PodSecurity "restricted:latest"`.
- `validate.sh` termina con `RESULT: 7/7 controles OK`.

## 7. Criterios de aceptación

- **Funcionalidad**: 2 réplicas de web respondiendo a probe TCP :8080.
- **Seguridad**: todos los campos del §3 presentes; prueba negativa funciona.
- **Reproducibilidad**: bootstrap + edit + apply + validate corre dos veces sin dejar basura entre corridas (el bootstrap limpia `/tmp/k8s-16-01` al re-ejecutarse).

## 8. Validación

Automatizada: `bash tests/validate.sh`. Comprueba 7 controles vía `kubectl ... -o jsonpath` y la prueba negativa (`kubectl apply --dry-run=server`).

## 9. Preguntas de reflexión

- ¿Qué pasa si pones solo `warn=restricted` sin `enforce`? ¿Por qué eso puede ser deseable durante un rollout?
- ¿Por qué `allowPrivilegeEscalation: false` + `runAsNonRoot: true` no son redundantes?
- Si nginx-unprivileged escucha en 8080, ¿por qué no simplemente `NET_BIND_SERVICE` + puerto 80?
- ¿Qué cambia si el namespace `app` ya tenía Pods *antes* de aplicarle el label `enforce`?

## 10. Extensiones

- Añade un `NetworkPolicy` default-deny al namespace `app` + regla egress hacia `kube-dns`.
- Añade `appArmorProfile: RuntimeDefault` (K8s 1.30+) y verifica en `kubectl describe pod`.
- Reutiliza la Kyverno `verifyImages` del Ejemplo 02 contra una imagen propia firmada.

## 11. Limpieza

```bash
kubectl delete ns app --wait=false
rm -rf /tmp/k8s-16-01
# Si creaste cluster solo para esto:
# kind delete cluster --name k8s-16-01
```
