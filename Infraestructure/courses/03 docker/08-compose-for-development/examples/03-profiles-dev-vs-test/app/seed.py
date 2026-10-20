"""Seed sample data into the items table."""
from __future__ import annotations

import os

import psycopg

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:dev@db:5432/postgres")

ITEMS = ["alpha", "beta", "gamma"]


def main() -> None:
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT NOT NULL)"
            )
            cur.execute("DELETE FROM items")
            for name in ITEMS:
                cur.execute("INSERT INTO items (name) VALUES (%s)", (name,))
            conn.commit()
    print(f"seeded {len(ITEMS)} items")


if __name__ == "__main__":
    main()
