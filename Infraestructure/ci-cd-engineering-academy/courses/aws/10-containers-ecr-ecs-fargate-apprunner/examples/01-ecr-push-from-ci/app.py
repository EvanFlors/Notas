"""Minimal FastAPI app used to produce a container image for the ECR-like demo."""

from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="aws10-fastapi-demo")


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "aws10-fastapi-demo", "message": "hello from ECS-like container"}
