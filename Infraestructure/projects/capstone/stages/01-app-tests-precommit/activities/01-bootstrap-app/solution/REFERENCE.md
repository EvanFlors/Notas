# REFERENCE — bootstrap-app

Secuencia esperada:

```bash
mkdir -p /tmp/cap-01-01
cp -R projects/capstone/stages/01-app-tests-precommit/app /tmp/cap-01-01/app
cd /tmp/cap-01-01/app
python3 -m venv .venv && source .venv/bin/activate
pip install -U pip && pip install -e '.[dev]'
alembic upgrade head
uvicorn app.main:app --port 8765 &
UVICORN_PID=$!
sleep 2
curl -s localhost:8765/healthz
curl -s -X POST localhost:8765/tasks -H 'content-type: application/json' \
  -d '{"title":"capstone-smoke"}'
kill "$UVICORN_PID"
echo bootstrap-ok > /tmp/cap-01-01/DONE
```

Punto clave: tras `alembic upgrade head`, la tabla `tasks` ya existe. El POST
inserta una fila. El marker `DONE` existe para que `validate.sh` sepa que el
estudiante llegó al final sin tener que inspeccionar el estado del servidor.
