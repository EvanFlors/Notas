"""Minimal Postgres client that mimics the shape of a Cloud SQL + Auth Proxy
connection. The DSN points at localhost:5432: in production that port is held
open by cloud-sql-proxy; here it is held by a local Postgres container.
"""
from __future__ import annotations

import os
import sys

import psycopg


DSN = os.environ.get("DATABASE_URL", "postgresql://app:app@localhost:5432/appdb")


def main() -> int:
    with psycopg.connect(DSN, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id   SERIAL PRIMARY KEY,
                    name TEXT NOT NULL
                )
                """
            )
            cur.execute("TRUNCATE items RESTART IDENTITY")
            cur.executemany(
                "INSERT INTO items (name) VALUES (%s)",
                [("alpha",), ("beta",), ("gamma",)],
            )
            cur.execute("SELECT id, name FROM items ORDER BY id")
            for row in cur.fetchall():
                print(f"item: id={row[0]} name={row[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
