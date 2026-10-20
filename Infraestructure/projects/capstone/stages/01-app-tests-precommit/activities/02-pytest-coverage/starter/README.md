# Starter — pytest-coverage

Reutiliza la carpeta `app/` del stage. Crea `/tmp/cap-01-02/` y pega ahí los
dos entregables listados en el README padre:

```bash
mkdir -p /tmp/cap-01-02
cd /path/to/app
pytest -q --cov=app --cov-report=term-missing | tee /tmp/cap-01-02/coverage.txt
printf "no quedan branches sin cubrir\n" > /tmp/cap-01-02/JUSTIFICATION.md
```
