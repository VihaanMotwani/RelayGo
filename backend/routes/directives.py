"""REST endpoints for responder directives."""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter

from database import get_directives, get_pending_directives, insert_directive
from models import Directive
from routes.websocket import broadcast

router = APIRouter(prefix="/api/directives", tags=["directives"])


@router.post("")
async def create_directive(directive: Directive) -> dict:
    """Dashboard submits a new directive to relay to the mesh."""
    is_new = await insert_directive(directive)
    if is_new:
        await broadcast(directive.model_dump())
    return {"ok": True, "created": is_new}


@router.get("")
async def list_directives(limit: int = 100, zone: Optional[str] = None) -> list[dict]:
    """Return all directives (for dashboard display), optionally filtered by zone."""
    return await get_directives(limit=limit, zone=zone)


@router.get("/pending")
async def pending_directives(zone: Optional[str] = None) -> list[dict]:
    """Return directives not yet fetched by mobile gateway nodes, optionally filtered by zone."""
    return await get_pending_directives(zone=zone)
