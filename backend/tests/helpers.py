"""Shared packet factory helpers for tests."""

from __future__ import annotations

import time
import uuid


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
