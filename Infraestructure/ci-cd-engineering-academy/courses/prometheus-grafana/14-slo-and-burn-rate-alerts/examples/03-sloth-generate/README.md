# Example 03 — Generar reglas con Sloth

[Sloth](https://sloth.dev/) toma una especificación YAML de SLOs y emite un
`PrometheusRule` con los ingredientes de recording rules + alertas MWMBR siguiendo
la receta del SRE Workbook, sin que tengas que repetir la fórmula a mano.

## Archivos
- `slo.yaml` — Spec en formato Sloth v1 para `payments-availability` 99.9%.
- `expected-rules.yaml` — Salida de referencia (equivalente a lo que escribiríamos a mano) para comparar cuando Sloth no está disponible.
- `run.sh` — Intenta `sloth generate` vía Docker; si la imagen no está disponible, SKIPea con éxito y muestra el `expected-rules.yaml`.
- `validate.sh` — Valida con `promtool` el output generado (o el `expected-rules.yaml`).

## Ejecutar

```bash
bash run.sh
bash validate.sh
```

Ambos SKIPean con exit 0 si Docker no está disponible.

## Discusión

Ventajas de generar en vez de escribir:
- La fórmula MWMBR tiene 4 alertas * 2 ventanas = 8 queries; un typo rompe la precisión.
- Sloth normaliza nombres (`slo:sli_error:ratioXh`) y añade labels (`sloth_service`, `sloth_slo`, `sloth_id`) útiles para enrutar en Alertmanager.
- Commiteando el output al repo, `promtool test rules` sigue siendo la fuente de verdad en CI.

Trade-off: la salida es verbosa (~250 líneas por SLO). Revísala al menos una vez para entender qué hace.
