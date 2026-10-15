"""Integration tests that hit the real Postgres defined by DATABASE_URL."""
from __future__ import annotations

import os

import psycopg

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:dev@db:5432/postgres")


def test_db_select_one() -> None:
    with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            assert cur.fetchone() == (1,)


def test_items_table_can_be_created_and_used() -> None:
    with psycopg.connect(DATABASE_URL, connect_timeout=5) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT NOT NULL)"
            )
            cur.execute("DELETE FROM items")
            cur.execute("INSERT INTO items (name) VALUES (%s)", ("probe",))
            cur.execute("SELECT COUNT(*) FROM items")
            count = cur.fetchone()[0]
            assert count == 1
            conn.commit()
