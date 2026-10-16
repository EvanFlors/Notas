# obs-06-01 — Scrape de pods por annotation (guided-lab)

## 1. Identificación
- **ID:** `obs-06-01-scrape-pods-by-annotation`
- **Tecnología:** prometheus-grafana
- **Módulo:** 06-service-discovery
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto
En un cluster de verdad nadie mantiene `scrape_configs` a mano. El patrón es: cada equipo anota sus pods con `prometheus.io/scrape=true` y el Prometheus central los descubre automáticamente. Esta actividad reproduce ese patrón *a mano* (sin Operator) para entender qué está ocurriendo por debajo.

## 3. Objetivos
- Configurar `kubernetes_sd_configs` con `role: pod`.
- Aplicar relabel para filtrar por anotación.
- Verificar que un pod anotado aparece y uno no anotado **no** aparece.
- Promover anotaciones a labels Prometheus útiles (`namespace`, `pod`).

## 4. Prerrequisitos
- Conocimientos: módulos `obs-01` a `obs-05`.
- Software:
  - `kind` ≥ 0.23
  - `kubectl` ≥ 1.28
  - `docker` corriendo
- Permisos: ninguno externo (todo local).
- Infraestructura: ~2 GB RAM libres para el cluster kind.
- **Costos**: 0 USD (todo local).

> Si falta `kind` o `kubectl`, el script de validación hace **SKIP** limpio sin fallar.

## 5. Instrucciones

Trabajarás en `/tmp/obs06-lab-01` (scratch). El `starter/` contiene manifests esqueleto; el objetivo es completarlos y aplicarlos.

```bash
WORK=/tmp/obs06-lab-01
rm -rf "$WORK" && mkdir -p "$WORK"
cp -r starter/* "$WORK/"
cd "$WORK"
```

### Paso 1. Crear el cluster kind

```bash
kind create cluster --name obs06-lab --image kindest/node:v1.30.0
```

### Paso 2. Completar `prometheus-config.yaml`

Abre `prometheus-config.yaml`. Añade el bloque `relabel_configs` al scrape_config `k8s-pods` para:

1. `keep` sólo pods con annotation `prometheus.io/scrape=true`.
2. Permitir override de `__metrics_path__` vía `prometheus.io/path`.
3. Permitir override del puerto vía `prometheus.io/port`.
4. Promover `__meta_kubernetes_namespace` → `namespace` y `__meta_kubernetes_pod_name` → `pod`.

### Paso 3. Aplicar todo

```bash
kubectl apply -f namespaces.yaml
kubectl apply -f rbac.yaml
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus.yaml
kubectl apply -f apps.yaml
kubectl -n monitoring wait --for=condition=Ready pod -l app=prometheus --timeout=120s
```

### Paso 4. Validar

```bash
kubectl -n monitoring port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 &
sleep 3
curl -s localhost:9090/api/v1/targets
```

Deberías ver `app-annotated` como `UP` y `app-unannotated` **ausente**.

### Paso 5. Correr el validador

```bash
bash tests/validate.sh
```

## 6. Resultado esperado
- `/api/v1/targets` contiene `app-annotated` y no contiene `app-unannotated`.
- Los targets tienen labels `namespace=demo` y `pod=app-annotated-...`.
- `tests/validate.sh` imprime `OK (3/3)`.

## 7. Criterios de aceptación
- **Funcionalidad:** el relabel filtra correctamente.
- **Calidad:** labels promovidos tienen nombres estables (`namespace`, `pod`, no `kubernetes_namespace`).
- **Reproducibilidad:** aplicar los manifests desde cero produce el mismo resultado.
- **Seguridad:** la ClusterRole del ServiceAccount Prometheus se limita a verbos de lectura.

## 8. Validación
```bash
bash tests/validate.sh
```
Hace `SKIP` si no están `kind`/`kubectl`.

## 9. Preguntas de reflexión
- ¿Por qué `__meta_kubernetes_pod_annotation_prometheus_io_scrape` y no `__meta_kubernetes_pod_annotation_prometheus.io/scrape`?
- Si un pod expone 3 puertos, ¿cuántos targets genera `role: pod` por él? ¿Cómo filtras al que te interesa?
- ¿Qué diferencia hay entre `role: pod` y `role: endpoints` cuando el pod está detrás de un Service?

## 10. Extensiones
1. Añade un filtro para que SOLO se scrape el puerto llamado `metrics` (`__meta_kubernetes_pod_container_port_name`).
2. Añade un segundo scrape_config con `role: service` que descubra el propio Prometheus (`monitoring/prometheus`).
3. Añade un `NetworkPolicy` que permita el scrape pod→pod solo desde `monitoring`.

## 11. Limpieza
```bash
kill %1 2>/dev/null || true
kind delete cluster --name obs06-lab
rm -rf /tmp/obs06-lab-01
```
