# Notas de la solución — obs-05-02

## Decisiones

- **`env` y `team` en `external_labels`**: viven una sola vez, afectan a *todas* las muestras persistidas por este Prometheus. Ventaja: cero duplicación. Trade-off: no diferencian por job dentro del mismo Prom (si eso hiciera falta, se ponen en `relabel_configs` por job).
- **`instance=node1`**: se usó `target_label: instance` con `replacement: node1` directo (no se filtra por `source_labels` porque solo hay un target).
- **Blackbox**: patrón canónico `__address__ → __param_target → instance; __address__ := exporter_host`.
- **`promhttp_metric_handler_*` dropeados en los tres jobs**: Prometheus no soporta "regla global de `metric_relabel_configs`"; se repiten literalmente. En setups grandes se genera con template.
- **`probe_success` sobrevive**: solo se dropeó por nombre exacto, no por prefijo.

## Alternativas

- Habríamos podido usar un `labelkeep` con lista positiva de nombres de métrica — mucho más agresivo y riesgoso. Preferir drop específico.
- Si `node_exporter` corriera en 50 nodos, `instance=node1` no serviría; usaríamos `__address__` + `instance` canónico.
