# Ejemplo 03 — Enriquecimiento con el processor `k8sattributes`

Despliega un Collector con el processor `k8sattributes` y envía traces OTLP desde un Pod cualquiera; verás que el exporter `debug` imprime los spans con atributos `k8s.pod.name`, `k8s.namespace.name`, `k8s.node.name`, `k8s.pod.uid` adjuntados **automáticamente** — la app nunca los setea.

## Archivos

- `demo.sh` — pipeline completo con kind + Operator + Collector + un Pod que envía spans.
- `collector-k8sattrs.yaml` — `OpenTelemetryCollector` con `k8sattributes` + exporter `debug`.
- `telemetrygen-job.yaml` — un `Job` que corre `telemetrygen` para producir spans.

## Qué observar

1. El Operator crea un **ClusterRole + ClusterRoleBinding** porque detectó el processor `k8sattributes`.
2. El `pod_association` del processor mapea por **IP de conexión** → `k8s.pod.ip` → Pod.
3. En los logs del Collector, cada span muestra atributos `k8s.*` que la app nunca inyectó.

## Requisitos

`kind`, `kubectl`. Si falta, `SKIP:`.

## Ejecutar

```bash
bash demo.sh
```

## Limpieza

Automática. `KEEP=1` para dejar vivo.
