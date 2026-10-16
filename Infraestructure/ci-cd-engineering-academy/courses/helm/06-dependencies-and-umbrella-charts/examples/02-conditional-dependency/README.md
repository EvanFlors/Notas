# Ejemplo 02 — Dependencia condicional

## Qué muestra

Usar `condition:` para activar/desactivar un subchart desde `values`. El mismo chart, dos renders: con DB (dev) y sin DB (prod).

## Requisitos

- Helm ≥ 3.14.
- Internet para resolver `bitnami/postgresql`.

## Ejecutar

```bash
bash run.sh
```

El script:

1. Crea `/tmp/helm-ex-02` con un chart `myapp` que declara `postgresql` con `condition: db.enabled`.
2. Resuelve la dependencia.
3. Renderiza dos veces: con `db.enabled=true` y con `db.enabled=false`.
4. Verifica que el `StatefulSet` del subchart aparece/desaparece.

## Qué observar

- Con `db.enabled=true` el render incluye `StatefulSet` del subchart.
- Con `db.enabled=false` el `StatefulSet` desaparece — no hace falta tocar templates.
- El default en `values.yaml` es `false` (producción = default seguro); los overrides por entorno (`values-dev.yaml`) lo activan.

## Limpieza

```bash
bash cleanup.sh
```
