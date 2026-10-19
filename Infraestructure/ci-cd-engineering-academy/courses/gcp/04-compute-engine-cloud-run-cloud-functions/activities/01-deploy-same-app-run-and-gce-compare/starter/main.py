"""Minimal FastAPI app for local docker run and Cloud Run (starter)."""
from __future__ import annotations

import os

from fastapi import FastAPI

app = FastAPI(title="capstone-api", version="1.0.0")


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "capstone-api"}


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8080"))
    uvicorn.run(app, host="0.0.0.0", port=port)
