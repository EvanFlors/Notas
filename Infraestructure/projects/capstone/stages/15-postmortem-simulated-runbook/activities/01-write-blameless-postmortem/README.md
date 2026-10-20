# Actividad 15.01 — Escribir un postmortem blameless

> Tipo: **independent** · Tiempo estimado: **75 min**.

## Objetivo

A partir del escenario de `../../incident/scenario.md`, producir un postmortem
completo siguiendo la plantilla Google SRE (`../../postmortem/TEMPLATE.md`).
El entregable debe pasar el validador automático y estar listo para peer review.

## Setup

```bash
mkdir -p /tmp/cap-15-01
cp ../../postmortem/TEMPLATE.md /tmp/cap-15-01/postmortem.md
# Opcional: tener a mano el escenario
cp ../../incident/scenario.md /tmp/cap-15-01/scenario.md
```

Edita `/tmp/cap-15-01/postmortem.md` rellenando todas las secciones. **No** copies
`REFERENCE.md` tal cual: trabaja desde la plantilla.

## Reglas

- Todas las secciones de la plantilla deben estar presentes y no vacías.
- La timeline debe tener al menos 6 eventos con formato `HH:MM`.
- Debe haber al menos 3 action items; cada uno con owner y due date; **al menos uno
  de tipo `preventive`**.
- Prohibidas palabras bandera: `fault of`, `blame`, `stupid`, `careless`, `idiot`,
  `culpa de`. El validador rechaza su presencia.
- La causa raíz debe tener al menos dos pasos de "porque" (técnica + proceso).

## Validación

```bash
bash tests/validate.sh /tmp/cap-15-01
```

Resultado esperado: `0 issue(s)`.

## Entregable

- `/tmp/cap-15-01/postmortem.md` que pasa el validador.
- Opcional: copiar el archivo a `postmortem/2026-04-17-pool-exhaustion.md` del
  repo del capstone cuando esté pulido.

## Hints progresivos (si te atascas)

1. ¿Tienes la timeline antes del texto largo? Si no, escríbela primero en una tabla.
2. ¿Tus `## N. Section` matchean exactamente los títulos de la plantilla? El validador
   los busca por prefijo (`## 1. Summary`, `## 2. Impact`, ...).
3. ¿Tus action items están en una tabla Markdown con columnas Owner y Due? El validador
   busca ambas columnas con esos nombres exactos.
