"""
RelayGo Backend — Shared test fixtures and testbench logging.

Provides DUT/Testbench-style logging prefixes:
  [STIMULUS]   — what JSON is being driven into the system
  [DUT]        — what the backend component does
  [SCOREBOARD] — pass/fail verdict with expected vs actual
  [TESTBENCH]  — fixture/setup lifecycle events
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import pathlib
import sys
import time
import uuid
from typing import AsyncIterator, Generator

import pytest
from fastapi.testclient import TestClient
from httpx import ASGITransport, AsyncClient

# ---------------------------------------------------------------------------
# Ensure the backend package is importable from the tests/ subdirectory.
# ---------------------------------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import database  # noqa: E402  — must be after sys.path fix


# ── Testbench Logger ────────────────────────────────────────────────────────

class _TestbenchFormatter(logging.Formatter):
    """Adds wall-clock and tag colouring to log lines."""

    def format(self, record: logging.LogRecord) -> str:
        ts = time.strftime("%H:%M:%S", time.localtime(record.created))
        ms = int(record.created * 1000) % 1000
        return f"  {ts}.{ms:03d}  {record.getMessage()}"


def _make_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(_TestbenchFormatter())
        logger.addHandler(handler)
    return logger


@pytest.fixture()
def tb(request) -> logging.Logger:
    """Testbench logger available to every test via `tb` fixture."""
    logger = _make_logger(f"testbench.{request.node.name}")
    logger.info(f"[TESTBENCH] ═══ {request.node.name} ═══")
    return logger


# ── Database Isolation ──────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def _tmp_db(tmp_path: pathlib.Path):
    """Redirect database to a fresh temp file per test."""
    test_db = tmp_path / "test_relaygo.db"
    original = database.DB_PATH
    database.DB_PATH = test_db
    yield test_db
    database.DB_PATH = original


# ── Async HTTP Client ──────────────────────────────────────────────────────

@pytest.fixture()
async def client(_tmp_db) -> AsyncIterator[AsyncClient]:
    """Async HTTPX client targeting the FastAPI ASGI app."""
    from main import app
    import database as db_mod

    await db_mod.init_db()
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


# ── Sync Client (for WebSocket tests) ──────────────────────────────────────

@pytest.fixture()
def sync_client(_tmp_db) -> Generator[TestClient, None, None]:
    """Starlette sync TestClient — needed for websocket_connect."""
    import database as db_mod

    asyncio.get_event_loop().run_until_complete(db_mod.init_db())
    from main import app

    with TestClient(app) as tc:
        yield tc


# ── Packet Factory Helpers ─────────────────────────────────────────────────

def make_report(**overrides) -> dict:
    """Return a valid EmergencyReport dict with optional overrides."""
    base = {
        "kind": "report",
        "id": str(uuid.uuid4()),
        "ts": int(time.time()),
        "loc": {"lat": 37.77, "lng": -122.41, "acc": 10.0},
        "type": "fire",
        "urg": 3,
        "haz": ["smoke"],
        "desc": "Building fire on 3rd floor",
        "src": "device-aaa",
        "hops": 0,
        "ttl": 10,
    }
    base.update(overrides)
    return base


def make_msg(**overrides) -> dict:
    """Return a valid MeshMessage dict with optional overrides."""
    base = {
        "kind": "msg",
        "id": str(uuid.uuid4()),
        "ts": int(time.time()),
        "src": "device-bbb",
        "name": "Alice",
        "to": None,
        "body": "Road blocked on 5th St",
        "hops": 0,
        "ttl": 10,
    }
    base.update(overrides)
    return base
