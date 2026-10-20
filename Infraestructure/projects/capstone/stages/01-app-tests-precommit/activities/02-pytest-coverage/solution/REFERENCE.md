# REFERENCE — pytest-coverage

El `app/tests/` del stage ya alcanza el gate de 80 %. Secuencia de atajo para
cerrar la actividad honestamente:

```bash
mkdir -p /tmp/cap-01-02
cd projects/capstone/stages/01-app-tests-precommit/app
source .venv/bin/activate
pytest -q --cov=app --cov-report=term-missing | tee /tmp/cap-01-02/coverage.txt
cat > /tmp/cap-01-02/JUSTIFICATION.md <<'EOF'
La rama no cubierta es el guard `if DATABASE_URL.startswith("sqlite")` en
`app/db.py` cuando `DATABASE_URL` apunta a Postgres: en el ciclo de pruebas
sólo usamos SQLite in-memory, por lo que la rama Postgres no se exercita.
Cubrirla exigiría arrancar un contenedor en pytest, lo cual se posterga a la
etapa 4 (Docker Compose dev).
EOF
```

Clave pedagógica: el reporte `term-missing` imprime las líneas que faltan por
cubrir; el estudiante debe mirar ese output y decidir si vale la pena añadir
un test o justificar el gap.
