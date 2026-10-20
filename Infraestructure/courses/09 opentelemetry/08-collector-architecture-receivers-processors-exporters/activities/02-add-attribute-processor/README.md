# Actividad 02 — Anadir un attributes processor

## 1. Identificacion

- **ID:** `otel-08-02-add-attribute-processor`
- **Tecnologia:** opentelemetry
- **Modulo:** 08-collector-architecture-receivers-processors-exporters
- **Dificultad:** intermediate
- **Duracion estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

Un patron muy comun en platform teams: *la plataforma* se encarga de marcar `deployment.environment` (prod/stg/dev) en toda la telemetria, para que los equipos de aplicacion no se olviden. Esto se hace en el Collector con un processor; evita que un servicio nuevo "escape" del contrato sin esa label.

Tu trabajo: modificar la config del Collector para que **todos los spans y todos los data points de metrica** que entren por el receiver `otlp` salgan con el atributo `deployment.environment = prod`.

## 3. Objetivos

- Elegir y configurar un processor adecuado (`attributes` o `resource` o `transform`).
- Insertarlo en el **orden correcto** dentro de las pipelines `traces` y `metrics`.
- Verificar via `file` exporter que el atributo aparece en los JSON de salida.

## 4. Prerrequisitos

- Haber completado la actividad 01 (o entender su setup).
- **Software:** `docker` corriendo. `grep`. Opcional: `jq`.
- **Puertos:** `4317` libre.
- **Costos:** cero.

## 5. Instrucciones

**Esta es una actividad independiente. No damos la solucion; damos pistas.**

1. Lee `starter/config.yaml`. Es casi igual al de la actividad 01 pero *sin* el processor que necesitas anadir.
2. Decide **que processor** usar. Opciones validas (cualquiera de las 3):
   - `attributes` processor con `action: upsert`.
   - `resource` processor (si queres pensarlo como atributo del *productor*, no del span).
   - `transform` processor con OTTL (`set(attributes["deployment.environment"], "prod")`).
3. Decide **donde** insertarlo en `service.pipelines.traces.processors` y `service.pipelines.metrics.processors`. Recuerda:
   - `memory_limiter` siempre primero.
   - `batch` siempre ultimo.
   - Enriquecedores en el medio.
4. Valida la config:
   ```sh
   docker run --rm -v "$PWD/starter/config.yaml:/c.yaml:ro" \
     otel/opentelemetry-collector-contrib:latest validate --config=/c.yaml
   ```
5. Lanza el collector + envia telemetria igual que en la actividad 01 (puedes copiar `starter/run-collector.sh` y `starter/send-signals.sh` de alla, o usar `tests/validate.sh` que hace todo).
6. Verifica manualmente:
   ```sh
   grep -o 'deployment.environment' /tmp/otel-lab-02/traces.jsonl | head
   grep -o 'prod' /tmp/otel-lab-02/metrics.jsonl | head
   ```

## 6. Resultado esperado

- `/tmp/otel-lab-02/traces.jsonl` contiene al menos una ocurrencia de la cadena `deployment.environment` **con** el valor `prod` cerca.
- Lo mismo para `/tmp/otel-lab-02/metrics.jsonl`.
- La config pasa `otelcol-contrib validate`.

## 7. Criterios de aceptacion

- La config incluye el processor adicional y lo referencia **en el orden correcto** en las dos pipelines (`traces` y `metrics`).
- Los JSONL contienen `deployment.environment` con valor `prod`.
- `memory_limiter` sigue primero; `batch` sigue ultimo.

## 8. Validacion

```sh
bash tests/validate.sh
```

El script:
1. Verifica que `docker` esta disponible (sino `SKIP`).
2. Lanza el collector con tu `starter/config.yaml` modificado.
3. Envia traces y metrics con telemetrygen.
4. Busca `deployment.environment` **y** `prod` en los dos jsonl.
5. Limpia.

## 9. Preguntas de reflexion

1. Diferencia entre `attributes` y `resource` processors en terminos del data model OTel.
2. Que ventaja da OTTL frente al simple `attributes` para este caso? Y la desventaja?
3. Que pasaria si pusieras el processor **despues** de `batch`?
4. Como extender esto para que `deployment.environment` sea leido de una variable de entorno del container en vez de hardcoded?

## 10. Extensiones

- Hacer que el valor venga de `${env:DEPLOYMENT_ENV}` (var de entorno del Collector).
- Anadir una pipeline mas (`logs`) con el mismo procesamiento.
- Usar `transform` para condicionar: `set(..., "prod") where resource.attributes["service.name"] != "sandbox"`.

## 11. Limpieza

```sh
docker rm -f otel-lab-collector-02 2>/dev/null || true
rm -rf /tmp/otel-lab-02
```
