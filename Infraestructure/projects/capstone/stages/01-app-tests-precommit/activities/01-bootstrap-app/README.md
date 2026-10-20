# Actividad 01 — Bootstrap de la app

Levanta la app `capstone-app` del stage 1 desde cero y comprueba que responde.

## Pasos

1. Copia el contenido de `starter/` a `/tmp/cap-01-01/` y entra ahí.
2. Crea el venv e instala la app con deps de dev.
3. Corre `alembic upgrade head`.
4. Arranca `uvicorn app.main:app --port 8765` (puerto arbitrario para no chocar).
5. Verifica `curl /healthz` y crea una tarea con `curl -X POST /tasks`.

## Entregable

- Fichero `/tmp/cap-01-01/DONE` con la línea `bootstrap-ok` tras hacer el roundtrip.
- Base SQLite `/tmp/cap-01-01/app/app.db` con al menos un registro en `tasks`.

## Validar

```bash
bash tests/validate.sh /tmp/cap-01-01
```

Si no tienes `pytest` o Python 3.12 instalados, la validación se marca como SKIP (no falla).
