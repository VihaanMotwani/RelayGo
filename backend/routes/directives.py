"""REST endpoints for responder directives."""

from __future__ import annotations

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
async def list_directives(limit: int = 100) -> list[dict]:
    """Return all directives (for dashboard display)."""
    return await get_directives(limit=limit)


@router.get("/pending")
async def pending_directives() -> list[dict]:
    """Return directives not yet fetched by mobile gateway nodes."""
    return await get_pending_directives()
