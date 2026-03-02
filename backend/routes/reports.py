"""REST endpoints for emergency reports and mesh messages."""

from __future__ import annotations

from fastapi import APIRouter

from backend.database import (
    get_reports,
    get_reports_geojson,
    insert_message,
    insert_report,
)
from backend.models import BatchUpload, EmergencyReport, MeshMessage
from backend.routes.websocket import broadcast

router = APIRouter(prefix="/api/reports", tags=["reports"])


@router.post("")
async def upload_batch(batch: BatchUpload) -> dict:
    """Ingest a batch of reports and/or messages from a mesh node."""
    new_reports: list[dict] = []
    inserted_reports = 0
    inserted_messages = 0

    for packet in batch.packets:
        if isinstance(packet, EmergencyReport):
            is_new = await insert_report(packet)
            if is_new:
                inserted_reports += 1
                new_reports.append(packet.model_dump())
        elif isinstance(packet, MeshMessage):
            is_new = await insert_message(packet)
            if is_new:
                inserted_messages += 1

    # Push newly-inserted reports to all connected dashboards.
    if new_reports:
        await broadcast(new_reports)

    return {
        "ok": True,
        "inserted_reports": inserted_reports,
        "inserted_messages": inserted_messages,
    }


@router.get("")
async def list_reports(limit: int = 100) -> list[dict]:
    """Return the most recent reports."""
    return await get_reports(limit=limit)


@router.get("/geojson")
async def reports_geojson() -> dict:
    """Return all reports as a GeoJSON FeatureCollection."""
    return await get_reports_geojson()
