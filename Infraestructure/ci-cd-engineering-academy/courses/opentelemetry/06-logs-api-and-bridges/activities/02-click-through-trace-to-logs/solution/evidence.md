# Evidencia — otel-06-02

- El trace capturado tiene 3 spans anidados: `receive` (root) > `validate` > `charge`.
- Query LogQL manual usada para localizar los logs del trace:
  `{service_name="otel-06-02-demo"} | json | trace_id="<trace-id-del-run>"`.
- Click-through en Grafana: en Tempo abro el trace, click en el span `validate` → aparece "Logs for this span" con el `logger.info("validando orden")`.
- Decisiones para produccion:
  - Mantener como labels de Loki solo `service_name`, `deployment_environment`, `severity_text`.
  - `order_id`, `amount` y el propio `trace_id` quedan dentro del body (indexado via `| json`) para no explotar la cardinalidad.
