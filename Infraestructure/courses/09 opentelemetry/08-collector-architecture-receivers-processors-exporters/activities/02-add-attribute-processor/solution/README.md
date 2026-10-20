# Solucion — Actividad 02

Tres caminos validos. El test acepta cualquiera que haga aparecer `deployment.environment` con valor `prod` en los jsonl.

## Opcion A — `attributes` processor (recomendado por simplicidad)

```yaml
processors:
  attributes/env:
    actions:
      - key: deployment.environment
        value: prod
        action: upsert
```

Referenciar en las pipelines:

```yaml
pipelines:
  traces:
    processors: [memory_limiter, attributes/env, batch]
  metrics:
    processors: [memory_limiter, attributes/env, batch]
```

## Opcion B — `resource` processor

Si quieres marcar la propiedad como del *productor* y no del span individual:

```yaml
processors:
  resource/env:
    attributes:
      - key: deployment.environment
        value: prod
        action: upsert
```

## Opcion C — `transform` con OTTL

Mas poderoso (permite condicionales). Overkill para este caso pero demuestra el patron:

```yaml
processors:
  transform/env:
    trace_statements:
      - context: span
        statements:
          - set(attributes["deployment.environment"], "prod")
    metric_statements:
      - context: datapoint
        statements:
          - set(attributes["deployment.environment"], "prod")
```

## Por que `attributes` vs `resource`

- `attributes` modifica el atributo del **span/metric/log individual**.
- `resource` modifica el atributo del **Resource** (todo lo producido por ese productor comparte el Resource).

`deployment.environment` es, segun las semantic conventions, un atributo de **Resource** — pero el test busca la cadena en el JSON de salida sin importar donde este, asi que ambas opciones pasan.

## Error comun

Ponerlo despues de `batch`. El orden `[memory_limiter, batch, attributes/env]` es ineficiente: batcheas y luego modificas; mejor modificas y luego batcheas.
