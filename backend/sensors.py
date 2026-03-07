"""Async polling service and infrastructure data loader for RelayGo.

- Loads static emergency infrastructure (hospitals, shelters, fire stations) into memory.
- Polls data.gov.sg v1 endpoints for real-time traffic camera images (every 60s).

Data is held in memory and pushed to dashboard via WebSocket.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import aiohttp

from routes.websocket import broadcast

logger = logging.getLogger("sensors")

BASE = "https://api.data.gov.sg/v1/transport"

ENDPOINTS = {
    "cameras": f"{BASE}/traffic-images",
}

# Poll intervals in seconds
INTERVALS = {
    "cameras": 120,
}

# Common headers — data.gov.sg blocks non-standard User-Agents
_HEADERS = {
    "User-Agent": "curl/8.0",
    "Accept": "application/json",
}

# Path to the processed data relative to the backend directory
INFRA_JSON_PATH = Path("../data_pipeline/data/processed/emergency_resources.json").resolve()


@dataclass
class SensorStore:
    """In-memory store for the latest sensor readings and infrastructure."""

    infra: list[dict[str, Any]] = field(default_factory=list)
    cameras: dict[str, Any] = field(default_factory=dict)
    last_updated: dict[str, float] = field(default_factory=dict)

    def snapshot(self) -> dict[str, Any]:
        """Return the full state for REST / initial WS load."""
        return {
            "kind": "sensors",
            "infra": self.infra,
            "cameras": self.cameras,
            "last_updated": {k: v for k, v in self.last_updated.items()},
        }


_store = SensorStore()


def get_latest() -> dict[str, Any]:
    """Return latest sensor snapshot (called by REST route)."""
    return _store.snapshot()


def get_cameras() -> dict[str, Any]:
    """Return just the camera data."""
    return {
        "kind": "sensors_cameras",
        "cameras": _store.cameras,
        "last_updated": _store.last_updated.get("cameras"),
    }


# ── Parsers ────────────────────────────────────────────────────────

def _parse_cameras(raw: dict) -> dict[str, Any]:
    """Extract traffic camera data.

    v1 format: { items: [{ timestamp, cameras: [...] }] }
    Each camera has: camera_id, location, image, timestamp, image_metadata
    """
    try:
        items = raw.get("items", [])
        if not items:
            return {}

        cameras_list = items[0].get("cameras", [])

        cameras = []
        for cam in cameras_list:
            cameras.append({
                "id": cam.get("camera_id", ""),
                "lat": cam.get("location", {}).get("latitude"),
                "lng": cam.get("location", {}).get("longitude"),
                "image_url": cam.get("image", ""),
                "timestamp": cam.get("timestamp", ""),
            })

        return {
            "cameras": cameras,
            "total": len(cameras),
        }
    except Exception as e:
        logger.warning("Failed to parse cameras: %s", e)
        return {}


_PARSERS = {
    "cameras": _parse_cameras,
}

def load_infrastructure():
    """Load the static emergency_resources.json file into the store."""
    try:
        if INFRA_JSON_PATH.exists():
            with open(INFRA_JSON_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                # Filter out AEDs as they are too numerous and clutter the map
                filtered_data = [item for item in data if not (item.get("name") == "AED_LOCATIONS" or item.get("type", "").lower() == "aed")]
                _store.infra = filtered_data
                _store.last_updated["infra"] = time.time()
                logger.info(f"Loaded {len(filtered_data)} infrastructure resources from {INFRA_JSON_PATH} (filtered out {len(data) - len(filtered_data)} AEDs)")
        else:
            logger.warning(f"Infrastructure JSON not found at {INFRA_JSON_PATH}")
    except Exception as e:
        logger.error(f"Failed to load infrastructure data: {e}")


# ── Polling loop ───────────────────────────────────────────────────

async def _poll_endpoint(
    session: aiohttp.ClientSession,
    name: str,
    url: str,
) -> None:
    """Fetch one endpoint and update the store."""
    try:
        async with session.get(
            url,
            timeout=aiohttp.ClientTimeout(total=15),
            headers=_HEADERS,
        ) as resp:
            if resp.status != 200:
                logger.warning("Sensor %s returned %s", name, resp.status)
                return
            raw = await resp.json()
    except Exception as e:
        logger.warning("Sensor %s fetch failed: %s", name, e)
        return

    parser = _PARSERS.get(name)
    if not parser:
        return

    parsed = parser(raw)
    if not parsed:
        return

    setattr(_store, name, parsed)
    _store.last_updated[name] = time.time()
    logger.info("Sensor %s updated successfully", name)

    # Push update to connected dashboards
    try:
        await broadcast({
            "kind": "sensors",
            "feed": name,
            "data": parsed,
            "ts": _store.last_updated[name],
        })
    except Exception as e:
        logger.warning("Sensor broadcast failed: %s", e)


async def _poll_loop(name: str, url: str, interval: int, initial_delay: float = 0) -> None:
    """Continuously poll a single endpoint."""
    if initial_delay > 0:
        await asyncio.sleep(initial_delay)
    async with aiohttp.ClientSession() as session:
        while True:
            await _poll_endpoint(session, name, url)
            await asyncio.sleep(interval)


async def start_polling() -> list[asyncio.Task]:
    """Load static data and start background polling tasks. Returns tasks."""
    # First load local infrastructure JSON synchronously once
    load_infrastructure()

    tasks = []
    for i, (name, url) in enumerate(ENDPOINTS.items()):
        interval = INTERVALS.get(name, 60)
        delay = i * 3.0  # stagger by 3s to avoid rate limits
        task = asyncio.create_task(
            _poll_loop(name, url, interval, initial_delay=delay),
            name=f"sensor_{name}",
        )
        tasks.append(task)
        logger.info("Started sensor polling: %s (every %ds, initial delay %.0fs)", name, interval, delay)

    return tasks
