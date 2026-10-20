"""FastAPI application entrypoint."""

from __future__ import annotations

from fastapi import FastAPI

from app import __version__
from app.db import Base, engine
from app.routers import health, tasks


def create_app() -> FastAPI:
    app = FastAPI(title="Capstone API", version=__version__)
    # Create tables on cold-start for SQLite dev convenience. In prod paths
    # (Postgres), Alembic owns the schema and this is a no-op since tables
    # already exist.
    Base.metadata.create_all(bind=engine)
    app.include_router(health.router)
    app.include_router(tasks.router)
    return app


app = create_app()
