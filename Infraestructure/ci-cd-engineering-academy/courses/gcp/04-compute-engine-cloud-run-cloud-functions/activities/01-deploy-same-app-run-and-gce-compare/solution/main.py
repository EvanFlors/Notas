"""Reference app. Identical to starter — image is the deliverable."""
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

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
