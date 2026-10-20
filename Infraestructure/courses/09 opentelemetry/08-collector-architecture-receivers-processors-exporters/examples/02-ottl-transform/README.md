# Ejemplo 02 — transform processor con OTTL

## Objetivo

Mostrar como el processor `transform` usa **OTTL** (OpenTelemetry Transformation Language) para enriquecer, condicionar y limpiar atributos sin recompilar nada.

## Que hace esta config

Sobre cada **span** entrante:

1. Setea `deployment.environment = "prod"` en todos los spans.
2. Setea `team = "payments"` **solo** si `resource.attributes["service.name"] == "checkout"`.
3. Elimina el atributo `pii.email` (compliance).

Sobre cada **data point de metrica**:

1. Setea `deployment.environment = "prod"` en todas las metricas.

## Archivos

- `config.yaml` — la configuracion.

## Validar

```sh
docker run --rm \
  -v "$PWD/config.yaml:/etc/otelcol/config.yaml:ro" \
  otel/opentelemetry-collector-contrib:latest \
  validate --config=/etc/otelcol/config.yaml
```

El binario `core` NO incluye `transform`; hay que usar **contrib**.

## OTTL rapido

- **Contextos**: `span`, `spanevent`, `datapoint`, `log`, `resource`.
- **Funciones de accion**: `set`, `delete_key`, `keep_keys`, `limit`, `replace_pattern`, `truncate_all`, `hash`.
- **Condiciones**: `where <expr>` al final de la statement.
- **Accesos**: `attributes["k"]`, `resource.attributes["k"]`, `name`, `status.code`, `kind`.

## Antipatron evitado

Para "setea un atributo fijo en todo", el processor `attributes` es mas legible:

```yaml
attributes:
  actions:
    - key: deployment.environment
      value: prod
      action: upsert
```

OTTL brilla cuando necesitas **condicional** o **transformacion**: ahi el `attributes` processor no alcanza.
