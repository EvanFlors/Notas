# Ejemplo 03 — `kubectl explain` como documentación del API

## Concepto que demuestra

`kubectl explain` NO consulta docs externas: lee el **OpenAPI schema** que el apiserver publica en `/openapi/v3`. Esto significa que:

- Siempre refleja la versión real de tu cluster.
- Funciona sobre CRDs que tú instales, sin cambios.
- Es el camino más rápido para contestar "¿qué campos tiene `X.spec.Y`?".

Aquí lo usamos sobre `Deployment.spec.strategy` como caso típico.

## Contexto

Explorarás una ruta del árbol del API con tres niveles de detalle: el objeto completo, un subcampo, y "todo recursivo". Esto reemplaza buscar en Google el 90 % de las veces.

## Objetivo

Al terminar sabrás:

- Cómo navegar `Deployment.spec.strategy.rollingUpdate.maxSurge`.
- Qué significa `--recursive` y cuándo úsarlo (con cuidado — mucho texto).
- Cómo consultar la URL cruda del OpenAPI schema con `kubectl proxy` y ver que efectivamente ahí vive la verdad.

## Prerrequisitos

- Cluster kind arriba.
- `kubectl` apuntando al contexto correcto.

## Ejecución

```bash
# 1. El objeto completo: Deployment. Verás metadata, spec, status y descripciones.
kubectl explain deployment | head -30

# 2. Un nivel abajo: Deployment.spec.
kubectl explain deployment.spec | head -40
#   Verás campos: replicas, selector, template, strategy, revisionHistoryLimit,
#   paused, progressDeadlineSeconds, minReadySeconds.

# 3. El campo que nos interesa: strategy.
kubectl explain deployment.spec.strategy
#   Verás que es un objeto con DOS campos:
#     - type: "Recreate" | "RollingUpdate" (default: "RollingUpdate")
#     - rollingUpdate: ... (solo aplica si type=RollingUpdate)

# 4. Un nivel más abajo: rollingUpdate.
kubectl explain deployment.spec.strategy.rollingUpdate
#   maxSurge     — IntOrString  (default: 25%)
#   maxUnavailable — IntOrString  (default: 25%)

# 5. Cada campo final, con su descripción completa.
kubectl explain deployment.spec.strategy.rollingUpdate.maxSurge
kubectl explain deployment.spec.strategy.rollingUpdate.maxUnavailable

# 6. "Todo recursivo", solo los nombres (útil para auditar).
kubectl explain deployment.spec.strategy --recursive
#   Imprime el árbol sin descripciones; bueno para ver nombres de campos
#   rápido. Sobre "deployment" entero, usar --recursive imprime cientos
#   de líneas.

# 7. Verlo "de donde sale": el OpenAPI schema crudo.
kubectl proxy --port=8001 >/tmp/k8s-02-ex03-proxy.log 2>&1 &
PROXY_PID=$!
sleep 2

# El schema vive aquí. Es GRANDE; filtramos a la ruta de Deployment.
curl -s http://127.0.0.1:8001/openapi/v3/apis/apps/v1 \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
dep = data['components']['schemas']['io.k8s.api.apps.v1.DeploymentStrategy']
print(json.dumps(dep, indent=2))
" | head -40
#   Esto es, textualmente, lo que kubectl explain reformatea.

# 8. Limpiar el proxy.
kill "$PROXY_PID" 2>/dev/null

# 9. explain también sobre recursos cluster-scoped y CRDs.
kubectl explain node.status.capacity
kubectl explain configmap.data
# Si tuvieras instalado cert-manager:
# kubectl explain certificate.spec.dnsNames
```

## Resultado esperado

- `kubectl explain deployment.spec.strategy.rollingUpdate.maxSurge` imprime la descripción con el tipo IntOrString y el default 25%.
- El JSON crudo del OpenAPI schema coincide (semánticamente) con lo que mostró `kubectl explain`.

## Limpieza

```bash
kill "$PROXY_PID" 2>/dev/null
rm -f /tmp/k8s-02-ex03-proxy.log
```

## Preguntas de reflexión

1. Si instalas una CRD de un operador y haces `kubectl explain <recurso>.spec`, ¿por qué funciona sin que `kubectl` sepa nada previo sobre esa CRD?
2. ¿Qué pasa si corres `kubectl explain pod.spec.containers.image` con un `kubectl` MUY vieja contra un cluster muy nuevo? ¿Qué version del schema se usa?
3. `maxSurge` acepta un int (`2`) o un string (`"25%"`). ¿Qué es `IntOrString` en los schemas de Kubernetes y por qué existe?
4. ¿Por qué `--recursive` sin un path concreto es peligroso en una terminal pequeña? (Mide: `kubectl explain pod --recursive | wc -l`).
