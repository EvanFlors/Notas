# Ejemplo 01 — Primera regla de alerta + test `promtool`

Minimo reproducible: una regla `HighErrorRate` basada en RED y su test unitario en `promtool`.

## Archivos
- `alerts.yaml` — la regla Prometheus.
- `tests.yaml` — dos casos: trafico con 5xx (debe disparar a los 10m) y trafico sano (no debe disparar).

## Ejecutar

Si tienes `promtool` instalado:

```bash
promtool check rules alerts.yaml
promtool test rules tests.yaml
```

Si no, con Docker (sin instalar nada):

```bash
docker run --rm --entrypoint promtool -v "$PWD":/w -w /w prom/prometheus:latest check rules alerts.yaml
docker run --rm --entrypoint promtool -v "$PWD":/w -w /w prom/prometheus:latest test rules tests.yaml
```

Salida esperada:

```
Checking alerts.yaml
  SUCCESS: 1 rules found

  SUCCESS
```

## Puntos de aprendizaje
- `for: 10m` fuerza al test a esperar hasta `eval_time >= 10m` antes de ver la alerta.
- `exp_alerts: []` tambien es una assertion: *no debe disparar*.
- `input_series` admite `0+10x30` (empieza en 0, suma 10 cada minuto, 30 puntos).
