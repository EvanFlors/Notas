# Starter — obs-01-02-identify-pillars-in-a-scenario

No hay código inicial: la actividad es puramente conceptual.

## Pasos mínimos

```bash
mkdir -p /tmp/obs-01-pillars
cd /tmp/obs-01-pillars
touch PILLARS.md
```

Luego sigue la sección 5 del `README.md` de la actividad.

## Esqueleto sugerido para `PILLARS.md`

```markdown
# obs-01-02 — Pilares en el postmortem de shop-api

## A. Mapeo pregunta → pilar

| # | Pregunta | Pilar primario | Pilar de apoyo | Señal concreta que hace falta |
|---|----------|----------------|----------------|-------------------------------|
| 1 | Patrón temporal              | metrics  | events  | ... |
| 2 | ¿Está pasando ahora?         | metrics  | —       | ... |
| 3 | Qué dijo bank-adapter a las ...| logs   | traces  | ... |
| 4 | Dónde se perdió el tiempo    | traces   | metrics | ... |
| 5 | Fallos por acquirer          | metrics  | logs    | ... |
| 6 | Correlación con deploy       | events   | metrics | ... |
| 7 | CPU por función              | profiling| metrics | ... |
| 8 | Patrón User-Agent            | logs/traces | metrics | ... |

## B. Lagunas de observabilidad

### Laguna 1 — ...
...

### Laguna 2 — ...
...

(hasta al menos 5)

## C. Monitoring vs observabilidad

1. Qué fue monitoring: ...
2. Qué fue falta de observabilidad: ...
3. Una señal única a añadir: ...
```

Rellena con tu criterio.
