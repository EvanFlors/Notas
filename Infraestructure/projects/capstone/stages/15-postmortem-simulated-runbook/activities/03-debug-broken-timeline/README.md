# Actividad 15.03 — Reparar un postmortem roto

> Tipo: **debug** · Tiempo estimado: **40 min**.

## Objetivo

Te entregan un postmortem redactado con prisa después de un incidente. Tiene tres
clases de problemas:

1. **Lenguaje culpabilizante** (contiene palabras como `blame`, `careless`, `culpa de`).
2. **Timeline incompleta**: pocos eventos y algunos sin `HH:MM`.
3. **Action items huérfanos**: faltan `Owner` y/o `Due` en varias filas.

Tu trabajo es dejarlo pasando el validador (`0 issue(s)`) sin cambiar los hechos.
Solo puedes editar lenguaje, estructura y metadatos.

## Setup

```bash
mkdir -p /tmp/cap-15-03
cp starter/postmortem.md /tmp/cap-15-03/postmortem.md
```

Edita `/tmp/cap-15-03/postmortem.md` hasta que el validador reporte `0 issue(s)`.

## Reglas

- No puedes falsear datos. Si no sabes un dato (p.ej. un owner), usa un **rol**
  genérico (`platform-team`, `sre-team`) y una fecha realista dentro de 1-4 semanas.
- Las reformulaciones blameless deben preservar la lección. Por ejemplo:
  "el dev olvidó revisar X" → "no existía un gate que forzara revisar X".
- La timeline debe quedar con **≥ 6 eventos** `HH:MM` en orden cronológico.

## Validación

```bash
bash tests/validate.sh /tmp/cap-15-03
```

Esperado: `0 issue(s)`.
