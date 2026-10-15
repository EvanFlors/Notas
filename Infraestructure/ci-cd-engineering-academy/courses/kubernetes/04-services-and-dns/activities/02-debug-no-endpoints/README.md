# k8s-04-02 — Depurar un Service sin endpoints (independiente)

## 1. Identificación

- **ID:** `k8s-04-02-debug-no-endpoints`
- **Tecnología:** kubernetes
- **Módulo:** `04-services-and-dns`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** debug (independiente — no te damos la respuesta)

## 2. Contexto

Alguien de otro equipo (tú, hace tres semanas) desplegó una app y un Service. "No responde". El Deployment tiene todas sus réplicas Ready, el Service existe con su `CLUSTER-IP` asignado, no hay NetworkPolicies, no hay firewall. `curl` desde un Pod cliente simplemente cuelga.

Esta es, de lejos, la primera clase de bug de Services en K8s. La causa suele ser pequeña y silenciosa: un **label selector mismatch**. El Service y los Pods viven en universos paralelos porque nadie compara **manualmente** `svc.spec.selector` con `pod.metadata.labels`.

Tu trabajo: diagnosticar y aplicar el **arreglo mínimo**.

## 3. Objetivos

- Reconocer que `endpoints` vacío es la señal técnica del problema.
- Explicar en una frase **por qué** está vacío.
- Aplicar el arreglo tocando el **Service**, no el Deployment (los Pods ya están corriendo con sus labels; cambiarlos reiniciaría todo).
- Verificar que `endpoints` se puebla y `curl` responde `HTTP 200`.

## 4. Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, Docker daemon arriba.
- Haber completado `k8s-04-01`.
- Sin costo.

## 5. Instrucciones

### Paso 1 — Monta el escenario roto

```bash
mkdir -p /tmp/k8s-04-02 && cd /tmp/k8s-04-02

kind delete cluster --name k8s04-act2 >/dev/null 2>&1 || true
kind create cluster --name k8s04-act2 --wait 90s
kubectl config use-context kind-k8s04-act2

bash courses/kubernetes/04-services-and-dns/activities/02-debug-no-endpoints/starter/build-broken.sh
```

El script aplica un `Deployment` llamado `web` (3 réplicas, imagen `nginx:alpine`) y un `Service` llamado `web` tipo `ClusterIP`. Deja todo "aparentemente bien".

### Paso 2 — Reproduce el síntoma

```bash
# El Service existe y tiene CLUSTER-IP:
kubectl get svc web

# Las réplicas están corriendo:
kubectl get pods -l app=web -o wide

# Pero esto cuelga (o devuelve "Connection refused"):
kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet --timeout=30s -- \
  curl -sS -o /dev/null -w "HTTP %{http_code}\n" --max-time 5 http://web || echo "fallo esperado"
```

### Paso 3 — Diagnostica

**No sigas al Paso 4 sin haber mirado estas tres cosas:**

```bash
# Lo primero siempre: ¿hay endpoints?
kubectl get endpoints web

# Si está vacío (lo estará): ¿qué dice el describe del Service?
kubectl describe svc web

# ¿Qué labels REALMENTE tienen los Pods?
kubectl get pods --show-labels
```

Compara **lo que selecciona el Service** con **lo que tienen los Pods**. La causa está entre esas dos líneas.

### Paso 4 — Aplica el arreglo

Modifica el **Service** (no los Pods) para que el `selector` sí matchee con las labels reales del Deployment. El arreglo correcto es una línea.

Puedes hacerlo con `kubectl edit svc web`, con `kubectl patch`, o reaplicando un YAML. Lo que te resulte natural.

> Regla de la actividad: **no toques el Deployment**. Simula un entorno de producción donde no quieres rotar los Pods para resolver un bug de red.

### Paso 5 — Verifica

```bash
kubectl get endpoints web
#   Ahora debe mostrar 3 IPs.

kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet -- \
  curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://web
#   Esperado: HTTP 200.
```

### Paso 6 — Entregable escrito

Crea `/tmp/k8s-04-02/diagnostico.md` con el formato:

```markdown
# Diagnóstico — k8s-04-02

- Síntoma observado:
- Comando que reveló la causa:
- Causa raíz (en 1-2 frases):
- Arreglo mínimo aplicado:
- Evidencia de que ahora funciona:
```

### Paso 7 — Validar

```bash
bash courses/kubernetes/04-services-and-dns/activities/02-debug-no-endpoints/tests/validate.sh
```

## 6. Resultado esperado

- `kubectl get endpoints web` lista 3 backends con puerto 80.
- `curl http://web` desde un Pod cliente → `HTTP 200`.
- Las labels del Deployment **no cambiaron** respecto al starter.
- `/tmp/k8s-04-02/diagnostico.md` existe y menciona `endpoints`, `selector` y la causa.

## 7. Criterios de aceptación

- El validador imprime `RESULT: PASS`.
- No introdujiste trucos (NodePort, hostNetwork, etc.) para "falsear" la conectividad.
- No borraste y recreaste el Deployment para forzar nuevas labels: cambiaste el **Service**.

## 8. Validación

```bash
bash courses/kubernetes/04-services-and-dns/activities/02-debug-no-endpoints/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `kubectl describe svc` no te dice "selector mal escrito"? ¿Qué garantía da (o no) el API server sobre que un selector matchee algo?
2. Si el bug fuera que `targetPort: 8080` en el Service pero el Pod escucha en 80, ¿`endpoints` estaría vacío? (Pista: no. ¿Qué otra señal verías?)
3. Nombra otras dos causas distintas por las que `endpoints` podría estar vacío **aun con selector correcto**.
4. ¿Cómo evitarías este bug a nivel de proceso (CI, linter, convención)?

## 10. Extensiones

- Añade un `kubectl diff` entre el manifest "roto" y el "arreglado" y pégalo en el diagnóstico.
- Instala `kubectl-neat` o `kubeconform` y valida el manifest antes de aplicar.
- Repite el escenario con 2 Deployments distintos y un Service cuyo selector matchee ambos: ¿qué pasa con `endpoints`?

## 11. Limpieza

```bash
kind delete cluster --name k8s04-act2
rm -rf /tmp/k8s-04-02
```
