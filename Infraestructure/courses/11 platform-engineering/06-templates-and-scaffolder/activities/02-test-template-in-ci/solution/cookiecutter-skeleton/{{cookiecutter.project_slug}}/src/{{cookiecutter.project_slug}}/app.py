"""Entry point for {{ cookiecutter.project_slug }}."""
from fastapi import FastAPI

app = FastAPI(title="{{ cookiecutter.project_slug }}")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
