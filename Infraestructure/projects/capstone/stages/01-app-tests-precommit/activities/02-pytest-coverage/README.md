# Actividad 02 — Pytest + coverage >= 80 %

Partiendo del `app/` del stage 1, escribe suficientes pruebas para que
`pytest -q` termine en verde con el gate de cobertura (`--cov-fail-under=80`)
satisfecho.

## Objetivos

- Cubrir happy path y errores (404, 422).
- Correr pytest con `--cov-report=term-missing` y entender los números.
- Elegir *una* branch que decides no cubrir y justificar por qué.

## Entregables (bajo `/tmp/cap-01-02/`)

- `coverage.txt`: la salida literal de `pytest --cov=app --cov-report=term-missing`.
- `JUSTIFICATION.md`: 1 párrafo explicando la branch no cubierta (si cubres el
  100 %, escribe "no quedan branches sin cubrir").

## Validar

```bash
bash tests/validate.sh /tmp/cap-01-02
```
