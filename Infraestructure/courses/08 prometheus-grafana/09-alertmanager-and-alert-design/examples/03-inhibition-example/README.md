# Ejemplo 03 — Inhibition para suprimir cascadas

Tres patrones de `inhibit_rules`:

1. `NodeDown` **suprime** `TargetDown` del mismo `cluster`+`node`.
2. `severity=critical` suprime `severity=warning` del mismo `alertname`+`service`.
3. `DatabaseDown` suprime `AppHighErrorRate` para apps con label `depends_on=db` en el mismo `cluster`.

## Como funciona el matching
- `source_matchers:` debe estar **firing** en Alertmanager.
- `target_matchers:` identifica a quienes suprimir.
- `equal:` fuerza igualdad de esas labels entre source y target. Sin esto, un nodo caido en `us-east` suprimiria targets de `eu-west` — nunca lo que queremos.

## Validar

```bash
docker run --rm --entrypoint amtool -v "$PWD":/w -w /w prom/alertmanager:latest \
  check-config alertmanager.yml
```

Esperado: `3 inhibit rules`.

## Nota
La inhibicion ocurre solo en Alertmanager. En Prometheus `/alerts` se veran todas firing — es correcto.
