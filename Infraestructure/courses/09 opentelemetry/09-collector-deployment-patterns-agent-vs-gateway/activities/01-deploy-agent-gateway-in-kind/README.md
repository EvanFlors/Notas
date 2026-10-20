# otel-09-01 — Desplegar agent + gateway en kind

## 1. Identificación

- **ID:** `otel-09-01-deploy-agent-gateway-in-kind`
- **Tecnología:** opentelemetry
- **Módulo:** 09-collector-deployment-patterns-agent-vs-gateway
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir, de cero, la topología de referencia **agent + gateway** en un cluster **kind** local. El objetivo no es "que funcione" sino que puedas defender cada decisión: dónde vive cada processor, qué compone el pipeline del agent y qué compone el pipeline del gateway, cómo el agent descubre al gateway, y cómo verificas que los spans emitidos por un workload llegan al backend.

## 3. Objetivos

- Crear un cluster kind de 2 nodos.
- Desplegar `otel-gateway` como Deployment + Service en namespace `observability`.
- Desplegar `otel-agent` como DaemonSet en el mismo namespace, apuntando al Service del gateway.
- Generar tráfico OTLP con `telemetrygen` **enviado al agent** (no al gateway directamente) y confirmar que llega al gateway.
- Pasar el validador automático en `tests/validate.sh`.

## 4. Prerrequisitos

- Conocimientos: `otel-08`; manejo básico de kind/kubectl.
- Software: `kind` ≥ 0.22, `kubectl` ≥ 1.29, Docker en ejecución.
- Infraestructura: una máquina con ≥ 4 GB RAM libres.
- Costos: 0.

## 5. Instrucciones

1. Lee `starter/README.md` y la carpeta `starter/` — contiene un `kind-config.yaml` listo y **esqueletos** de manifiestos con huecos marcados `# TODO`.
2. Completa los TODO:
   - En `starter/agent.yaml`: define el `exporters.otlp.endpoint` apuntando al Service DNS del gateway (`otel-gateway.observability.svc.cluster.local:4317`), añade `tls.insecure: true` dentro del cluster, y referencia el exporter en los pipelines de traces/metrics/logs.
   - En `starter/gateway.yaml`: define el exporter `debug` (verbosity `basic`) y asegúrate de que las 3 pipelines usan `memory_limiter → batch → debug`.
3. Ejecuta `bash tests/setup.sh` para crear el cluster y aplicar tus manifiestos.
4. Envía telemetría de prueba: `bash tests/send-traces.sh` (lanza un Job de `telemetrygen` que apunta al **agent** del nodo donde cae, usando el Service DNS del agent interno).
5. Ejecuta `bash tests/validate.sh`. Debe reportar `OK` en los 5 checks.

Si el validador falla, lee el mensaje: cada check indica exactamente qué recurso falta o qué log no apareció.

## 6. Resultado esperado

- Namespace `observability` con:
  - DaemonSet `otel-agent` (pods Ready = número de nodos).
  - Deployment `otel-gateway` (replicas Ready ≥ 1).
  - Service `otel-gateway` con endpoints poblados.
- Log del gateway contiene al menos un batch `ResourceSpans`.
- `tests/validate.sh` → exit 0 y mensaje "ALL CHECKS PASSED".

## 7. Criterios de aceptación

- **Funcionalidad**: tráfico fluye SDK → agent → gateway → backend-debug.
- **Topología**: el agent envía al gateway por nombre DNS del Service, no por IP.
- **Resiliencia**: ambas capas tienen `memory_limiter`; el agent tiene `sending_queue` activo.
- **Operabilidad**: `health_check` extension expuesta y usada por readiness probes.
- **Reproducibilidad**: `tests/setup.sh` es idempotente.

## 8. Validación

```bash
bash tests/setup.sh
bash tests/send-traces.sh
bash tests/validate.sh
```

El validador comprueba 5 checks (ver el script para el detalle).

## 9. Preguntas de reflexión

1. ¿Por qué el `telemetrygen` apunta al Service del agent y no al del gateway directamente? ¿Qué ganarías/perderías si apuntase al gateway?
2. Si quitaras el `batch` processor en el agent y lo dejaras solo en el gateway, ¿qué cambia en el comportamiento observable? (pista: RPS entre agent y gateway).
3. ¿Qué pasaría si el gateway se cayera durante 2 minutos? ¿Qué cambiaría si activaras `file_storage` en el agent?
4. ¿Cómo escalarías el gateway si llegaras a 10× la carga?
5. ¿Qué distro del Collector elegirías si este cluster corriera en EKS exportando a Amazon Managed Prometheus? ¿Por qué?

## 10. Extensiones

- **E1.** Activa `file_storage` en el agent (volumen `hostPath`) y verifica persistencia simulando caída del gateway.
- **E2.** Añade un HPA al gateway (`type: Resource`, CPU 70 %) y genera carga con 10 × `telemetrygen` concurrentes.
- **E3.** Añade `k8sattributes` processor en el agent para enriquecer con `k8s.pod.name`, `k8s.namespace.name`. Verifica en el log del gateway que los nuevos atributos aparecen (RBAC: necesitas un `ServiceAccount` con permisos get/list/watch de Pods).

## 11. Limpieza

```bash
bash tests/cleanup.sh
```

Borra el cluster kind y `/tmp/otel-09-01-*`.
