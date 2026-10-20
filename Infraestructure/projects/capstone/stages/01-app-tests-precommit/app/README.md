# Capstone App — Stage 1

FastAPI + SQLAlchemy + Alembic baseline service.

Quick start:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -U pip && pip install -e '.[dev]'
alembic upgrade head
uvicorn app.main:app --reload --port 8000
pytest -q
```

See the parent `stages/01-app-tests-precommit/README.md` for the full stage guide.
