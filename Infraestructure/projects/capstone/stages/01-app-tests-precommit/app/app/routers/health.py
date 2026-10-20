"""Health endpoints."""

from __future__ import annotations

from fastapi import APIRouter

from app import __version__
from app.schemas import Health

router = APIRouter(tags=["health"])


@router.get("/healthz", response_model=Health)
def healthz() -> Health:
    """Liveness probe. Does not touch the database on purpose."""
    return Health(status="ok", version=__version__)
