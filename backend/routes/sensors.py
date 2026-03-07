"""REST endpoints for real-time infrastructure sensor data."""

from __future__ import annotations

from fastapi import APIRouter

from sensors import get_cameras, get_latest

router = APIRouter(prefix="/api/sensors", tags=["sensors"])


@router.get("")
async def sensor_snapshot() -> dict:
    """Return the latest snapshot of all sensor feeds."""
    return get_latest()


@router.get("/cameras")
async def camera_feed() -> dict:
    """Return traffic camera data (images + locations)."""
    return get_cameras()
