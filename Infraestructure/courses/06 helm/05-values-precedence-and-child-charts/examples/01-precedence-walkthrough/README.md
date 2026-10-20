# Ejemplo 01 — Precedence walkthrough

Chart mínimo que renderiza un `ConfigMap` con tres claves: `replicas`, `env` e `imageTag`. Cada clave es tocada por una fuente diferente para visualizar la cadena de precedencia.

## Archivos
- `mychart/values.yaml` — defaults (`replicas: 1`, `env: dev`, `imageTag: 0.0.0`).
- `mychart/values-prod.yaml` — override "entorno prod" (`replicas: 5`, `env: prod`).
- `mychart/values-override.yaml` — override "operador" (`replicas: 3`).
- `mychart/templates/configmap.yaml` — render.

## Pasos

1. **Solo defaults** — todo viene de `values.yaml`:
   ```bash
   helm template demo ./mychart
   ```
   Esperado: `replicas: "1"`, `env: "dev"`, `imageTag: "0.0.0"`.

2. **Un `-f`** — `values-prod.yaml` entra con mayor prioridad:
   ```bash
   helm template demo ./mychart -f mychart/values-prod.yaml
   ```
   Esperado: `replicas: "5"`, `env: "prod"`, `imageTag: "0.0.0"` (no tocado).

3. **Dos `-f`, orden importa** — `values-override.yaml` entra al final:
   ```bash
   helm template demo ./mychart -f mychart/values-prod.yaml -f mychart/values-override.yaml
   ```
   Esperado: `replicas: "3"` (último `-f` ganó sobre `-f` anterior), `env: "prod"` (solo el primero lo definía), `imageTag: "0.0.0"`.

4. **`-f` + `--set`** — `--set` siempre al final:
   ```bash
   helm template demo ./mychart \
     -f mychart/values-prod.yaml \
     -f mychart/values-override.yaml \
     --set imageTag=1.42.0 --set replicas=10
   ```
   Esperado: `replicas: "10"` (ganó `--set` sobre todo), `env: "prod"`, `imageTag: "1.42.0"`.

## Lectura

Cada paso corresponde a un nivel de la pirámide de precedencia descrita en la teoría (§2). Lo clave es internalizar que **el último que escribe gana** y que `--set` está siempre arriba.

## Ejecución rápida
```bash
cd examples/01-precedence-walkthrough
helm template demo ./mychart -f mychart/values-prod.yaml -f mychart/values-override.yaml --set imageTag=1.42.0
```
