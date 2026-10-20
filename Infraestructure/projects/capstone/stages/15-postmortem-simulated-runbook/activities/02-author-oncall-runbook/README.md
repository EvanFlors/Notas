# Actividad 15.02 — Escribir el runbook on-call para pool exhaustion

> Tipo: **independent** · Tiempo estimado: **60 min**.

## Objetivo

A partir de los aprendizajes del postmortem (actividad 15.01), producir un runbook
que una guardia **que no vivió el incidente** pueda ejecutar sin preguntar.

## Setup

```bash
mkdir -p /tmp/cap-15-02
cp ../../runbook/TEMPLATE.md /tmp/cap-15-02/runbook.md
```

## Reglas

- Todas las secciones de la plantilla deben estar presentes.
- La sección `Symptoms` debe listar al menos una alerta y un patrón de logs/métricas.
- La sección `Diagnostics` debe tener **al menos 2 pasos ejecutables** (bloques
  ``` ``` ```) y al menos 2 "descartes rápidos" (desambiguación con otros runbooks).
- La sección `Mitigations` debe tener **al menos 2 mitigaciones ordenadas** y mencionar
  al menos un *anti-patrón* ("No hagas: ...").
- La sección `Verification` debe tener al menos 4 checkboxes `- [ ]`.
- Prohibidas palabras bandera (igual que postmortem).

## Validación

```bash
bash tests/validate.sh /tmp/cap-15-02
```

Esperado: `0 issue(s)`.

## Entregable

- `/tmp/cap-15-02/runbook.md` que pasa el validador.
- Opcional: moverlo a `runbook/db-pool-exhaustion.md` del repo cuando esté pulido.
