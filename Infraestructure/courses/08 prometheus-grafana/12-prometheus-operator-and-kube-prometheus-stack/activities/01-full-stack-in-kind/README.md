# obs-12-01 — Stack kube-prometheus-stack completo sobre kind

## 1. Identificación
- **ID:** `obs-12-01-full-stack-in-kind`
- **Tecnología:** prometheus-grafana
- **Módulo:** `12-prometheus-operator-and-kube-prometheus-stack`
- **Dificultad:** advanced
- **Duración estimada:** 120 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a montar, de principio a fin, el "default moderno" de observabilidad en Kubernetes: un cluster kind, el chart `kube-prometheus-stack`, una app propia con `/metrics`, un `ServiceMonitor` que la scrape, y un dashboard de Grafana cargado desde un ConfigMap. El objetivo es que al terminar entiendas cada pieza, no que ejecutes `helm install` como un ritual.

## 3. Objetivos

- Diferenciar visualmente cada componente del stack mirando pods, CRDs y UIs.
- Hacer que un `ServiceMonitor` propio sea reconocido por el Prometheus del Operator.
- Verificar la relación label-selector que decide si el ServiceMonitor es visto.
- Cargar un dashboard sin tocar Grafana con el ratón.
- Dejarlo todo limpio con un script de teardown.

## 4. Prerrequisitos

- Conocimientos: Helm básico, kubectl, CRDs/Operators (k8s-14).
- Software: `docker` corriendo, `kind` ≥ 0.20, `kubectl` ≥ 1.28, `helm` ≥ 3.12.
- Infraestructura: ≥ 6 GB RAM libres, ≥ 2 CPUs, ≥ 10 GB disco libre.
- Costos: ninguno (todo local).
- Red: salida a `ghcr.io` y a los charts de `prometheus-community`.

## 5. Instrucciones

Esta actividad es guiada: todos los pasos están en `starter/bootstrap.sh`. Primero léelo, luego ejecútalo.

```bash
cd activities/01-full-stack-in-kind
less starter/bootstrap.sh      # entender antes de ejecutar

# Ejecutar
bash starter/bootstrap.sh
```

El script, de arriba a abajo:

1. Chequea prerrequisitos (docker, kind, kubectl, helm). Si falta algo, aborta con mensaje claro.
2. Crea un cluster kind llamado `obs12` con 1 control-plane + 1 worker.
3. Añade el repo Helm `prometheus-community` y crea el namespace `monitoring`.
4. Instala `kube-prometheus-stack` con un values apto para kind (desactiva `kubeControllerManager`/`Scheduler`/`Etcd`/`Proxy`, baja retention a 2d).
5. Crea el namespace `apps` y despliega la app `prometheus-example-app` + Service.
6. Aplica el ServiceMonitor con `labels.release: kps`.
7. Crea un ConfigMap con un dashboard JSON y la label `grafana_dashboard=1`.
8. Espera a que todo quede ready e imprime URLs de port-forward para explorar.

Una vez corra, abre:

- Prometheus → `http://localhost:9090/targets` — busca `apps/fastapi` como UP.
- Grafana → `http://localhost:3000` (admin/admin) — busca el dashboard "FastAPI Demo".
- Alertmanager → `http://localhost:9093`.

### Exploración manual recomendada

```bash
# Lista todos los CRDs del Operator
kubectl get crd | grep monitoring.coreos.com

# Mira el prometheus.yml que generó el Operator a partir de tus CRs
kubectl -n monitoring get secret prometheus-kps-kube-prometheus-stack-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' \
  | base64 -d | gunzip | less
```

## 6. Resultado esperado

- `kubectl -n monitoring get pods` muestra Operator + Prometheus + Alertmanager + Grafana + node-exporter + kube-state-metrics todos `Running`.
- `kubectl -n apps get servicemonitor fastapi` existe con label `release: kps`.
- El job `apps/fastapi/0` aparece como `UP` en Prometheus.
- El dashboard "FastAPI Demo" está visible en Grafana sin importar manual.
- `bash tests/validate.sh` termina con `OK`.

## 7. Criterios de aceptación

- **Funcionalidad**: los 5 checkpoints anteriores pasan.
- **Reproducibilidad**: `starter/bootstrap.sh` + `starter/teardown.sh` dejan el sistema igual que antes.
- **Seguridad**: ningún secreto hardcodeado real (`admin/admin` es un default de laboratorio, no de producción).
- **Mantenibilidad**: cada paso del bootstrap está comentado.

## 8. Validación

```bash
bash tests/validate.sh
```

El script degrada a `SKIP` si no hay `kubectl`, `kind` o si el cluster `obs12` no está. Cuando el cluster está arriba, verifica CRDs, namespaces, ServiceMonitor y ConfigMap de dashboard.

## 9. Preguntas de reflexión

1. ¿Por qué el `ServiceMonitor` necesita la label `release: kps` para ser recogido?
2. Si quitas esa label, ¿qué comando usarías para confirmar que el Operator lo ignoró?
3. ¿Qué pasaría si quitas la label `grafana_dashboard=1` del ConfigMap? ¿Y si la pones en el namespace equivocado?
4. ¿Por qué el chart desactiva `kubeControllerManager/Scheduler/Etcd` en kind?
5. ¿Qué comando te enseña el `prometheus.yml` *generado* por el Operator? ¿Por qué eso no es un ConfigMap?

## 10. Extensiones

1. Añade un segundo `ServiceMonitor` con una label *incorrecta* y usa el checklist de §6 (lesson) para diagnosticar por qué no aparece.
2. Añade una `PrometheusRule` sencilla (`sum(rate(http_requests_total[5m])) > 10 for 2m`) y dispárala con tráfico.
3. Reemplaza el dashboard JSON por uno importado de grafana.com (ID 7249 — "Kubernetes Cluster") convertido a ConfigMap.
4. Convierte todo a un `Application` de Argo CD y sincronízalo desde un repo Git local.

## 11. Limpieza

```bash
bash starter/teardown.sh
```

Esto borra el cluster `obs12` y los ficheros `/tmp/obs12-*`.
