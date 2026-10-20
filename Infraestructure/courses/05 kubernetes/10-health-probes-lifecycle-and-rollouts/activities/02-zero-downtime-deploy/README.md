# k8s-10-02 — Rollout de dos versiones sin un solo 5xx

## 1. Identificación

- **ID:** `k8s-10-02-zero-downtime-deploy`
- **Tecnología:** kubernetes
- **Módulo:** `10-health-probes-lifecycle-and-rollouts`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a desplegar nginx como stand-in de un servicio web, hacer dos rollouts consecutivos (v1 → v2 → v3), y **demostrar** con un cliente externo que no cae ni un solo request durante los rollouts. Para lograrlo necesitas combinar las cuatro piezas del módulo:

1. Probes correctas (startup, readiness, liveness).
2. `preStop` + `terminationGracePeriodSeconds` para absorber la ventana de carrera de red.
3. `maxSurge: 1, maxUnavailable: 0`.
4. Un `PodDisruptionBudget` que respalda el rollout.

El validador comprueba la *forma final* del manifiesto (los cuatro puntos arriba) y, si tienes un cluster disponible, puedes correr la demo completa.

## 3. Objetivos

- Producir un `deployment.yaml` con probes, preStop, terminationGracePeriodSeconds y PDB correctos.
- Opcionalmente, correr el rollout contra un cluster local y observar que un `curl` loop no ve 5xx.

## 4. Prerrequisitos

- Haber hecho `k8s-10-01` o leído la sección 6 y 8 de la lección.
- Para la parte opcional de ejecución real: cluster local kind/k3d funcional + `kubectl`.
- Sin costo. Sin secretos.

## 5. Instrucciones

Trabaja en `/tmp/k8s-10-02/`:

```bash
mkdir -p /tmp/k8s-10-02
cp starter/deployment.yaml /tmp/k8s-10-02/deployment.yaml
cd /tmp/k8s-10-02
```

### Paso 1 — probes

Edita `deployment.yaml`. Añade/corrige:

- `startupProbe` HTTP sobre `/` port `http`, ventana total >= 30 s.
- `readinessProbe` HTTP sobre `/` port `http`, `periodSeconds` 2..5, `failureThreshold` 2..3.
- `livenessProbe` HTTP sobre `/` port `http`, `periodSeconds` >= 10, `failureThreshold` >= 3.

(Para nginx todas apuntan a `/`; en una app real usarías `/healthz` y `/readyz` como en la actividad 01.)

### Paso 2 — terminación limpia

- Añade `terminationGracePeriodSeconds: 40` al Pod spec.
- Añade `lifecycle.preStop.exec.command` con un `sh -c "sleep 10"` (o similar >= 5 s).

### Paso 3 — estrategia de rollout

Dentro de `spec.strategy`:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### Paso 4 — PDB

Añade un segundo documento YAML al mismo archivo (separado por `---`) con un `PodDisruptionBudget`:

- `apiVersion: policy/v1`
- `kind: PodDisruptionBudget`
- `metadata.name`: `web-zdd`
- `spec.minAvailable: 2` (asumiendo `replicas: 3`)
- `spec.selector.matchLabels`: `{ app: web-zdd }`

### Paso 5 — valida la forma

```bash
bash tests/validate.sh
```

Debe pasar los 10+ checks.

### Paso 6 (opcional, pero muy recomendado) — corre el rollout real

Si tienes kind arriba:

```bash
kubectl apply -f /tmp/k8s-10-02/deployment.yaml
kubectl rollout status deployment/web-zdd --timeout=120s
kubectl expose deployment web-zdd --port=80 --target-port=http --name=web-zdd 2>/dev/null || true

# Load generator en-cluster
kubectl run loadgen --image=curlimages/curl:8.9.1 --restart=Never -- \
  sh -c 'c=0; e=0; while true; do \
    code=$(curl -sS -o /dev/null -w "%{http_code}" http://web-zdd/ || echo 000); \
    c=$((c+1)); \
    case "$code" in 2??) :;; *) e=$((e+1)); echo "ERR $code (total errs=$e / reqs=$c)";; esac; \
    sleep 0.1; done'

# En otra terminal, dispara el rollout v2:
kubectl set env deployment/web-zdd VERSION=v2
kubectl rollout status deployment/web-zdd --timeout=180s

# y luego v3:
kubectl set env deployment/web-zdd VERSION=v3
kubectl rollout status deployment/web-zdd --timeout=180s

# Observa logs del loadgen: no deben aparecer lineas "ERR ..."
kubectl logs loadgen | tail -20
```

## 6. Resultado esperado

- `tests/validate.sh` sale con exit 0.
- Si corriste el rollout real: `kubectl logs loadgen` **no** muestra lineas `ERR 5xx` ni `ERR 000` relacionadas con los rollouts.

## 7. Criterios de aceptación

- Deployment con `replicas: 3`, label `app: web-zdd`.
- Las tres probes presentes y bien formadas (ver paso 1).
- `terminationGracePeriodSeconds` >= 20.
- `lifecycle.preStop.exec.command` presente con sleep >= 5s.
- `strategy.rollingUpdate.maxSurge >= 1` y `maxUnavailable == 0`.
- PodDisruptionBudget `web-zdd` con `minAvailable: 2` apuntando al mismo selector.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `maxUnavailable: 0` + `maxSurge: 1` es más lento pero más seguro que los defaults?
2. ¿Qué pasaría si `terminationGracePeriodSeconds` fuera menor que el `preStop sleep`?
3. ¿Por qué el PDB con `minAvailable: 2` es consistente con `maxUnavailable: 0`? ¿Qué pasa si pones `minAvailable: 3`?
4. En una app real con conexiones gRPC largas, ¿bastaría con `preStop sleep 10`? ¿Qué más necesitarías?

## 10. Extensiones

- Añade `readinessGates` ficticia (ej. `conditionType: example.com/custom`) y observa que el Pod nunca pasa a Ready hasta que publiques la condition manualmente con `kubectl patch`.
- Usa `kubectl rollout pause` entre v1→v2 para verificar los primeros Pods antes de dejar correr el resto.
- Reproduce el error: pon `maxUnavailable: 1` y mide cuántos ERR aparecen.

## 11. Limpieza

```bash
kubectl delete pod loadgen --ignore-not-found
kubectl delete deployment web-zdd --ignore-not-found
kubectl delete svc web-zdd --ignore-not-found
kubectl delete pdb web-zdd --ignore-not-found
rm -rf /tmp/k8s-10-02
```
