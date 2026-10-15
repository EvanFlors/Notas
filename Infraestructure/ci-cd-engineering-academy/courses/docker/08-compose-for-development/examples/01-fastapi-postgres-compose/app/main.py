"""Minimal FastAPI app with a /db endpoint that opens a Postgres connection."""
from __future__ import annotations

import os

import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI()

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:dev@db:5432/postgres")


@app.get("/")
def root() -> dict[str, str]:
    return {"status": "ok", "service": "dkr-08-example-01"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/db")
def db_check() -> dict[str, object]:
    """Open a short-lived connection and run `SELECT 1`."""
    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=3) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                row = cur.fetchone()
        return {"db": "ok", "result": row[0] if row else None}
    except Exception as exc:  # noqa: BLE001 - we want the message in the HTTP body
        raise HTTPException(status_code=503, detail=f"db unavailable: {exc}") from exc
