# argo-10-01 — Canary de 4 pasos para el capstone

## 1. Identificación

- **ID:** `argo-10-01-canary-capstone`
- **Tecnología:** argocd-gitops
- **Módulo:** `10-argo-rollouts-progressive-delivery`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

El capstone del curso corre hoy con un `Deployment` estándar. Vas a convertirlo en un `Rollout` canary de 4 pasos — `setWeight: 10` → `pause 2m` → `setWeight: 50` → `pause {}` (manual) → `setWeight: 100` — con dos Services (`canary` y `stable`) para que, cuando añadas traffic management en una iteración futura, no haya que repintar nada.

Esta actividad **no** exige Prometheus. Es la base estructural; la actividad 02 añade el analysis.

## 3. Objetivos

- Producir un `rollout.yaml` válido con la estrategia canary de 4+ pasos.
- Dos Services (`capstone-stable`, `capstone-canary`) con el selector correcto.
- Validador estructural que pasa `tests/validate.sh`.
- Opcionalmente aplicar contra kind + Argo Rollouts y promover el canary.

## 4. Prerrequisitos

- Lección del módulo (`theory/lesson.md`), al menos secciones 3, 5, 6.
- Para la parte opcional de ejecución: cluster kind + Argo Rollouts (ver `examples/01-blue-green-with-services/README.md`).
- Sin costo. Sin secretos.

## 5. Instrucciones

Trabaja en `/tmp/argo-10-01/`:

```bash
mkdir -p /tmp/argo-10-01
cp starter/rollout.yaml /tmp/argo-10-01/rollout.yaml
cp starter/services.yaml /tmp/argo-10-01/services.yaml
cd /tmp/argo-10-01
```

### Paso 1 — convertir el Deployment en Rollout

El `starter/rollout.yaml` tiene un `kind: Deployment`. Cámbialo a:

- `apiVersion: argoproj.io/v1alpha1`
- `kind: Rollout`

El resto del template (containers, probes, resources) queda igual.

### Paso 2 — añadir `strategy.canary`

Dentro de `spec`, reemplaza (si existe) `strategy.type: RollingUpdate` por:

```yaml
strategy:
  canary:
    canaryService: capstone-canary
    stableService: capstone-stable
    maxSurge: 1
    maxUnavailable: 0
    steps:
      - setWeight: 10
      - pause: { duration: 2m }
      - setWeight: 50
      - pause: {}
      - setWeight: 100
```

### Paso 3 — Services

En `services.yaml` crea los dos Services apuntando al `app: capstone` del Rollout. Deben estar como *dos documentos YAML separados por `---`*.

### Paso 4 — valida

```bash
bash tests/validate.sh /tmp/argo-10-01
```

Debe pasar los 10+ checks.

### Paso 5 (opcional) — aplica y promueve

Si tienes cluster + Argo Rollouts:

```bash
kubectl apply -f /tmp/argo-10-01/services.yaml
kubectl apply -f /tmp/argo-10-01/rollout.yaml
kubectl argo rollouts status capstone --timeout 2m

# Dispara la rev 2:
kubectl patch rollout capstone --type merge \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"nginx:1.27"}]}}}}'
kubectl argo rollouts get rollout capstone --watch &

# En el pause manual tras setWeight: 50:
kubectl argo rollouts promote capstone
```

## 6. Resultado esperado

- `tests/validate.sh` sale con exit 0.
- Opcionalmente, el `Rollout` promovido a `revision 2` sin degraded.

## 7. Criterios de aceptación

- `kind: Rollout` con `apiVersion: argoproj.io/v1alpha1`.
- `metadata.name: capstone` y label `app: capstone`.
- `spec.strategy.canary` presente con los 5 pasos esperados.
- Al menos un `setWeight: 10`, un `setWeight: 50`, un `setWeight: 100`.
- Al menos un `pause: {}` (manual) y un `pause: { duration: ... }` (temporizado).
- `canaryService` y `stableService` definidos.
- Dos Services (`capstone-canary`, `capstone-stable`) seleccionando `app: capstone`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/argo-10-01
```

El validador acepta `BASE_DIR` o primer argumento. Default `/tmp/argo-10-01`.

## 9. Preguntas de reflexión

1. ¿Qué diferencia operativa hay entre `pause: {}` y `pause: { duration: 2m }`?
2. Con `replicas: 5` y `setWeight: 10`, ¿cuántos pods canario tendrás? ¿Qué porcentaje real de tráfico?
3. ¿Por qué tener `canaryService` y `stableService` separados aunque todavía no uses traffic management?
4. En producción, ¿dónde colocarías el step `analysis`?

## 10. Extensiones

- Añade un step `analysis` tras `setWeight: 50` con la plantilla de la actividad 02.
- Convierte el canary en blue/green (ver example 01) y compara DX.
- Añade `trafficRouting.nginx` y dos Ingress (ver `examples/02-canary-stepped-with-nginx/rollout-with-nginx.yaml`).

## 11. Limpieza

```bash
kubectl delete -f /tmp/argo-10-01/rollout.yaml --ignore-not-found
kubectl delete -f /tmp/argo-10-01/services.yaml --ignore-not-found
rm -rf /tmp/argo-10-01
```
