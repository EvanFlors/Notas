# Ejemplo 02 — Route tree multi-equipo + severidad

Config de Alertmanager con tres patrones utiles juntos:

1. **Fan-out por severidad** con `continue: true`: toda `severity=page` tambien va a PagerDuty.
2. **Enrutado por `team`** a Slack del equipo.
3. **Sub-ruta** por severidad dentro de cada equipo (page -> PagerDuty del equipo).
4. **`severity=info`** nunca pagina — va a webhook de tickets con `repeat_interval` largo.

## Validar

```bash
docker run --rm --entrypoint amtool -v "$PWD":/w -w /w prom/alertmanager:latest \
  check-config alertmanager.yml
```

Salida esperada:

```
Checking 'alertmanager.yml'  SUCCESS
Found:
 - global config
 - route
 - 0 inhibit rules
 - 7 receivers
 - 0 templates
```

## Probar el routing sin notificar

```bash
docker run --rm --entrypoint amtool -v "$PWD":/w -w /w prom/alertmanager:latest \
  config routes test --config.file=alertmanager.yml \
  severity=page team=payments alertname=X
```

Imprime los receivers a los que iria la alerta. Con los labels de arriba:

```
pagerduty-oncall,payments-pagerduty
```

Es decir: fan-out al PagerDuty general y al del equipo de payments.

## Nota sobre secretos
Las URLs y keys son placeholders. En produccion usar `api_url_file:` y `routing_key_file:` apuntando a Secrets montados; nunca commitear credenciales.
