# Ejemplo 01 — `grafonnet` baseline: un dashboard RED generado desde una libsonnet

## Qué muestra
Un `service.libsonnet` define "cómo es un dashboard RED para cualquier servicio". `dashboards/checkout-red.jsonnet` lo instancia para el servicio `checkout`. Al compilar con `jsonnet` sale el JSON que Grafana ingiere.

Es la base de la idea "cada servicio tiene su RED dashboard gratis": añadir un servicio = 3 líneas.

## Archivos
- `service.libsonnet` — plantilla reutilizable.
- `dashboards/checkout-red.jsonnet` — instancia para `checkout`.
- `dashboards/orders-red.jsonnet` — instancia para `orders` (demuestra reutilización).
- `render.sh` — compila a JSON y valida sintaxis con `python -m json.tool`.
- `expected/checkout-red.json` — snapshot esperado (regresión mínima).

## Requisitos
- `jsonnet` instalado (`brew install jsonnet` o binario de https://github.com/google/jsonnet/releases).
- `python3` (para validar JSON).
- No necesitas Grafana ni Prometheus para este ejemplo — es sólo generación.

## Correr

```bash
bash render.sh
```

Salida esperada: dos JSON en `out/` + mensaje `OK — all dashboards rendered and valid JSON`.

## Siguiente paso
En el ejemplo 02 verás cómo este output se publica a Grafana por `grizzly` desde un workflow de GitHub Actions con preview en PR.

## Notas
- Este ejemplo no vende el jsonnet puro como única opción. `cue`, Terraform o `grafanalib` sirven con el mismo patrón: declarar una "forma de dashboard" y rehidratarla por servicio.
- Nunca commitees el JSON compilado si tienes CI que lo regenera: evita drift. Aquí mantenemos `expected/*.json` sólo como snapshot pedagógico.
