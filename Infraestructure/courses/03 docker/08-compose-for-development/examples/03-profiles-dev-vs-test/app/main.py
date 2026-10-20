"""FastAPI with a /items endpoint backed by Postgres."""
from __future__ import annotations

import os

import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI()
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:dev@db:5432/postgres")


def _ensure_table() -> None:
    with psycopg.connect(DATABASE_URL, connect_timeout=3) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT NOT NULL)"
            )
            conn.commit()


@app.on_event("startup")
def on_startup() -> None:
    _ensure_table()


@app.get("/")
def root() -> dict[str, str]:
    return {"status": "ok", "service": "dkr-08-example-03"}


@app.get("/items")
def list_items() -> dict[str, list[dict]]:
    try:
        with psycopg.connect(DATABASE_URL, connect_timeout=3) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id, name FROM items ORDER BY id")
                rows = cur.fetchall()
        return {"items": [{"id": r[0], "name": r[1]} for r in rows]}
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=str(exc)) from exc
