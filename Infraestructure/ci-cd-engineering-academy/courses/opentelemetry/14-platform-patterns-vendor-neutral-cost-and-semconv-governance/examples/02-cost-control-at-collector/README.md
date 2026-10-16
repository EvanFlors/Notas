# Ejemplo 02 — Cost control at the Collector

Collector gateway que aplica las tres palancas de control de costo:

1. **Tail-based sampling** con quotas por servicio (y "errors / slow always").
2. **Drop de atributos de alta cardinalidad** antes del backend.
3. **Aggregation**: `cumulativetodelta` + `interval` para pre-agregar histogramas ruidosos.

## Archivos

- `collector.yaml` — configuración completa.
- `NOTES.md` — notas de operación: cómo ajustar policies por servicio, cómo medir el ahorro.

## Verificación estructural (opcional)

```bash
# Si tienes otelcol-contrib disponible:
otelcol-contrib validate --config examples/02-cost-control-at-collector/collector.yaml
```

No se ejecuta aquí; es un patrón de referencia.
