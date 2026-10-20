"""FastAPI app that persists items to Postgres via DATABASE_URL.

Local shape (Postgres in Docker) and Cloud SQL + Auth Proxy are
indistinguishable from the app's perspective: both expose a TCP socket
at the DSN's host:port speaking Postgres wire protocol.
"""
from __future__ import annotations

import os
from contextlib import asynccontextmanager
from typing import Any

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


DSN = os.environ.get("DATABASE_URL", "postgresql://app:app@localhost:5432/appdb")


class ItemIn(BaseModel):
    name: str


class Item(BaseModel):
    id: int
    name: str


def get_conn() -> psycopg.Connection[Any]:
    return psycopg.connect(DSN, autocommit=True)


def init_schema() -> None:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id   SERIAL PRIMARY KEY,
                name TEXT NOT NULL
            )
            """
        )


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_schema()
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    try:
        with get_conn() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=f"db unavailable: {exc}")
    return {"status": "ok"}


@app.post("/items", response_model=Item)
def create_item(payload: ItemIn) -> Item:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO items (name) VALUES (%s) RETURNING id, name",
            (payload.name,),
        )
        row = cur.fetchone()
    return Item(id=row[0], name=row[1])


@app.get("/items", response_model=list[Item])
def list_items() -> list[Item]:
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name FROM items ORDER BY id")
        rows = cur.fetchall()
    return [Item(id=r[0], name=r[1]) for r in rows]
