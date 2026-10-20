"""Minimal FastAPI scaffolding for ${{ values.name }}."""
from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="${{ values.name }}")


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "service": "${{ values.name }}"}
