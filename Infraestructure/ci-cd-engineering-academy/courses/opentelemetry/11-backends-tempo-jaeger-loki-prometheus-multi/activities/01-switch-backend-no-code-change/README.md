# Actividad 01 — Cambiar backend sin tocar código

## 1. Identificación

- **ID:** `otel-11-01-switch-backend-no-code-change`
- **Tecnología:** `opentelemetry`
- **Módulo:** `11-backends-tempo-jaeger-loki-prometheus-multi`
- **Dificultad:** advanced
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab

## 2. Contexto

Un servicio ya instrumentado con OTel exporta OTLP a un **OTel Collector** local. Hoy, el Collector reenvía esos traces a **Tempo**. Negocio pide evaluar **Jaeger** por su UI standalone. **Restricción:** no se puede tocar ni redeployar la app.

Esta es *exactamente* la promesa de OTel que vale la pena demostrar: el pipeline del Collector es el único lugar donde se decide el backend.

El `starter/setup.sh` prepara un stack base: `trace-gen` → `otel-collector` → `tempo` + `grafana`. Tu tarea es editar **únicamente** `otel-collector-config.yaml` y `docker-compose.yaml` para añadir **Jaeger** y cortar Tempo, dejando el servicio productor **sin cambios**.

## 3. Objetivos

- Añadir `jaeger-all-in-one` al `docker-compose.yaml`.
- Reemplazar el exporter `otlp/tempo` por `otlp/jaeger` en el pipeline `traces` del Collector.
- Verificar en la UI de Jaeger (`http://localhost:16686`) que los traces del servicio `trace-gen` siguen llegando.
- Verificar que la aplicación (`trace-gen`) **no se ha reiniciado** (mismo container id) ni cambiado su configuración.

## 4. Prerrequisitos

- `otel-08-collector-architecture-receivers-processors-exporters` completada.
- Docker + Docker Compose plugin disponibles y daemon corriendo.
- Puertos libres: `3000` (Grafana), `3200` (Tempo), `4317`/`4318` (OTLP), `16686` (Jaeger UI), `8888` (Collector self-telemetry).
- **Costos:** ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar el estado inicial (Tempo)

```bash
bash starter/setup.sh /tmp/otel11-lab01
cd /tmp/otel11-lab01
docker compose up -d
```

Espera ~20 s y verifica el estado inicial:

```bash
curl -fsS http://localhost:3200/ready
curl -fsS -G --data-urlencode 'tags=service.name=trace-gen' \
  --data-urlencode 'limit=1' http://localhost:3200/api/search | head -c 200
```

Deberías ver "ready" y JSON con al menos un `traceID`.

**Anota el container id del productor** — será la prueba de que no lo reiniciaste:

```bash
docker inspect -f '{{.Id}}' lab01-trace-gen > /tmp/trace-gen-id-before.txt
cat /tmp/trace-gen-id-before.txt
```

### 5.2 Añadir Jaeger

Edita `docker-compose.yaml` y añade un servicio Jaeger all-in-one:

```yaml
jaeger:
  image: jaegertracing/all-in-one:1.60
  container_name: lab01-jaeger
  environment:
    COLLECTOR_OTLP_ENABLED: "true"
  ports:
    - "16686:16686"   # UI
    - "14317:4317"    # OTLP gRPC (expuesto en 14317 para no chocar con el Collector)
```

### 5.3 Cambiar el pipeline del Collector

Edita `otel-collector-config.yaml`. Quita el exporter `otlp/tempo` del pipeline y añade `otlp/jaeger` apuntando a `jaeger:4317`:

```yaml
exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/jaeger]       # <-- antes era [otlp/tempo]
```

(Puedes dejar Tempo corriendo si quieres comparar; para esta actividad lo importante es que **el pipeline ya no lo alimenta**.)

### 5.4 Aplicar el cambio

El Collector no soporta hot-reload de pipelines en versiones recientes; reinícialo (solo el Collector, **no la app**):

```bash
docker compose up -d --force-recreate otel-collector
```

### 5.5 Verificar

```bash
# La app NO se reinició:
docker inspect -f '{{.Id}}' lab01-trace-gen > /tmp/trace-gen-id-after.txt
diff /tmp/trace-gen-id-before.txt /tmp/trace-gen-id-after.txt && echo "App container intact"

# Jaeger está recibiendo:
curl -fsS 'http://localhost:16686/api/services' | head -c 200
```

Luego abre la UI: `http://localhost:16686` → selecciona el servicio `trace-gen` → **Find Traces**.

### 5.6 Ejecutar el validador

```bash
bash tests/validate.sh /tmp/otel11-lab01
```

## 6. Resultado esperado

- `jaeger` corriendo (`docker compose ps`).
- Collector reiniciado, con `otlp/jaeger` en el pipeline `traces`.
- Contenedor `lab01-trace-gen` con el **mismo** container id que antes del cambio.
- `GET http://localhost:16686/api/services` devuelve una lista con `trace-gen`.
- `GET http://localhost:16686/api/traces?service=trace-gen&limit=5` devuelve ≥ 1 traza.

## 7. Criterios de aceptación

- [ ] Jaeger responde en `:16686` y lista `trace-gen` como servicio.
- [ ] El pipeline del Collector ya no contiene `otlp/tempo` como exporter activo.
- [ ] El container id de la app (`lab01-trace-gen`) es idéntico antes y después del cambio.
- [ ] No hay credenciales reales ni API keys en los configs.
- [ ] `docker compose down -v` limpia todo el estado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/otel11-lab01
```

El validador comprueba, en orden:

1. Jaeger `/api/services` responde con `trace-gen` dentro de la lista.
2. `otel-collector-config.yaml` ya **no** menciona `otlp/tempo` en el pipeline `traces`.
3. El container de `trace-gen` sigue siendo el original (compara contra `/tmp/trace-gen-id-before.txt` si existe).

Si Docker no está disponible, imprime `SKIP` y sale `0`.

## 9. Preguntas de reflexión

1. ¿Qué pasa si el pipeline sigue teniendo `otlp/tempo` **y además** `otlp/jaeger`? ¿Cuándo ese estado intermedio es útil y cuándo es un bug?
2. El exporter `otlp` del Collector contrib habla OTLP gRPC. Jaeger acepta OTLP desde v1.35+. ¿Qué pasaría con un Jaeger viejo que solo habla Thrift? ¿Qué cambiarías en el config?
3. La app no tuvo que cambiar. ¿Qué habría tenido que cambiar si estuviera usando `jaeger-client-python` nativo en vez de OTel? Enumera.
4. Si Jaeger se cae durante 10 min, ¿qué le pasa a los traces emitidos por la app? ¿Qué processor/configuración del Collector mitiga esa pérdida?
5. Diseña el procedimiento inverso: volver a Tempo. ¿Es simétrico? ¿Qué datos pierdes al cortar Jaeger?

## 10. Extensiones

- **E1** — Mantén **ambos** exporters durante 10 min (fan-out). Compara ambas UIs. Luego corta Tempo. Documenta en `NOTES.md`.
- **E2** — Añade `extensions: [health_check]` al Collector y haz que `tests/validate.sh` consulte `/healthz` como check adicional.
- **E3** — Reemplaza Jaeger por un backend compatible OTLP distinto (p. ej. SigNoz) y repite. ¿Qué fue trivial? ¿Qué tuvo fricción real?

## 11. Limpieza

```bash
cd /tmp/otel11-lab01 && docker compose down -v
rm -rf /tmp/otel11-lab01 /tmp/trace-gen-id-before.txt /tmp/trace-gen-id-after.txt
```
