"""WebSocket hub for real-time dashboard updates."""

from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()

# Connected dashboard clients.
_clients: set[WebSocket] = set()


@router.websocket("/ws/dashboard")
async def dashboard_ws(ws: WebSocket) -> None:
    await ws.accept()
    _clients.add(ws)
    try:
        # Keep the connection alive; ignore incoming frames.
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        _clients.discard(ws)
    except Exception:
        _clients.discard(ws)


async def broadcast(data: dict[str, Any] | list[dict[str, Any]]) -> None:
    """Push JSON data to every connected dashboard client."""
    payload = json.dumps(data)
    dead: list[WebSocket] = []
    for ws in _clients:
        try:
            await ws.send_text(payload)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _clients.discard(ws)
