# obs-06-02 — Debug: "mi pod no es scrapeado" (independent)

## 1. Identificación
- **ID:** `obs-06-02-debug-missing-targets`
- **Tecnología:** prometheus-grafana
- **Módulo:** 06-service-discovery
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** debug

## 2. Contexto
Te entregan 4 configuraciones Prometheus/K8s rotas. En todas, el equipo cree haber configurado K8s SD correctamente, pero `/api/v1/targets` está vacío (o incompleto). Tu trabajo es, en cada caso, encontrar la **causa raíz** y proponer un fix mínimo.

**No se da la solución**. El test valida que tus arreglos funcionan.

## 3. Objetivos
- Diagnosticar sistemáticamente por qué un target K8s no aparece.
- Distinguir fallos de SD (no se ve en `/service-discovery`) vs fallos de relabel (se ve ahí pero no en `/targets`) vs fallos de scrape (`DOWN`) vs fallos de RBAC.
- Aplicar fixes mínimos sin reescribir todo.

## 4. Prerrequisitos
- Haber completado `obs-06-01` o entendido el patrón de annotation.
- `kind` ≥ 0.23, `kubectl` ≥ 1.28, `docker`.
- 2 GB RAM libres para el cluster.
- **Costos**: 0 USD.

> Si falta `kind` o `kubectl`, el validador hace **SKIP** limpio.

## 5. Instrucciones

### Setup

```bash
WORK=/tmp/obs06-lab-02
rm -rf "$WORK" && mkdir -p "$WORK"
cp -r starter/* "$WORK/"
cd "$WORK"

kind create cluster --name obs06-debug --image kindest/node:v1.30.0
kubectl apply -f base/
kubectl -n demo wait --for=condition=Ready pod -l tier=app --timeout=120s
```

### Los 4 escenarios

Cada escenario vive en `scenarios/<N>/`. Cada uno aplica una **configuración rota** y expone un `Service` `prometheus-sN` en el namespace `monitoring`. Tu trabajo:

1. Aplicar la configuración rota: `kubectl apply -f scenarios/<N>/`.
2. `kubectl -n monitoring port-forward svc/prometheus-sN <PORT>:9090` y mirar `/targets` y `/service-discovery`.
3. Encontrar la causa.
4. Editar los YAML del escenario *in situ* para arreglarlo (mínimo cambio).
5. Reaplicar y confirmar que el pod `demo/app-x` (o el que corresponda) ahora aparece activo.

**Pistas por escenario (sin dar la respuesta):**

- `scenarios/1/` — "ya está anotado y aún así nada". Lee el YAML del pod con `kubectl get pod -o yaml` y compara con lo que mira Prometheus.
- `scenarios/2/` — "casi funciona pero el keep no deja pasar". El regex del relabel está demasiado estricto o mal escrito.
- `scenarios/3/` — "no veo ningún `__meta_*` para pods". El `role` del SD no es el correcto para esta app.
- `scenarios/4/` — "los logs del Prometheus dicen `cannot list resource`". Problema de permisos.

### Validar

```bash
bash tests/validate.sh
```

El validador aplica tus arreglos y comprueba que en cada escenario aparece el target esperado.

## 6. Resultado esperado
- 4 configuraciones corregidas con el **mínimo cambio** posible.
- Cada `prometheus-sN` muestra al menos un target `UP` del namespace `demo`.
- `tests/validate.sh` imprime `OK (4/4)`.

## 7. Criterios de aceptación
- **Funcionalidad:** los 4 escenarios validan.
- **Mínimo cambio:** no reescribes la configuración entera; cambias lo justo.
- **Comentarios:** cada archivo arreglado tiene un comentario `# FIX:` explicando qué estaba mal.
- **Reproducibilidad:** `rm -rf /tmp/obs06-lab-02 && repetir setup` reproduce la validación.

## 8. Validación
```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Qué consulta en Prometheus muestra los `__meta_*` disponibles antes del relabel?
- Si el log del Prometheus dice `pods is forbidden`, ¿qué CR o CRB necesitas editar?
- ¿Por qué `role: service` descubre endpoints via ClusterIP y `role: endpoints` los descubre uno por pod?
- ¿Cuál es la diferencia entre un target que no aparece y uno `DOWN`?

## 10. Extensiones
1. Añadir un quinto escenario donde el problema sea una `NetworkPolicy`.
2. Escribir un `kubectl` plugin de 20 líneas que diagnostique "falta anotación / RBAC / port name".

## 11. Limpieza
```bash
pkill -f 'kubectl.*port-forward' 2>/dev/null || true
kind delete cluster --name obs06-debug
rm -rf /tmp/obs06-lab-02
```
