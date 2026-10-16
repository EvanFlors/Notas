# Ejemplo 01 — Vendor-neutral contract

Muestra un contrato de plataforma escrito (markdown) y la configuración mínima del Collector que lo implementa. El contrato es la "ley"; el Collector es la "policía".

## Archivos

- `CONTRACT.md` — texto del contrato (versión 1, inspirado en lo que una plataforma pequeña puede publicar en el día 1).
- `collector.yaml` — Collector mínimo que recibe OTLP, aplica k8sattributes, batch, memory_limiter, y exporta a 3 backends neutrales (Tempo/Prometheus/Loki). Nada vendor-específico.

## Cómo leerlos

1. Lee `CONTRACT.md`. Fíjate que la sección "MUST NOT" prohíbe atributos propietarios en código.
2. Lee `collector.yaml`. Nota que **no hay** ningún exporter vendor; sólo OTLP y backends open-source.
3. Observa que el Collector es el único proceso que conoce la URL del backend. Si mañana cambia, se cambia aquí.

## Validación

```bash
# otelcol-contrib ya instalado en PATH (ver prerreqs del módulo)
otelcol-contrib validate --config examples/01-vendor-neutral-contract/collector.yaml
```

El validate no se ejecuta en este README (es sólo lectura); se usa en los ejemplos siguientes y en las actividades.
