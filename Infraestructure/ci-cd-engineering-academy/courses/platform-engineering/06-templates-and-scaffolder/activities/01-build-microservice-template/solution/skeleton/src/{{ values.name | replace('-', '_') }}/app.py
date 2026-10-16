"""Entry point for ${{ values.name }}."""
from fastapi import FastAPI

app = FastAPI(title="${{ values.name }}")


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}
