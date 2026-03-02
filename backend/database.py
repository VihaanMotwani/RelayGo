"""Async SQLite persistence layer for reports and messages."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import aiosqlite

from models import Directive, EmergencyReport, MeshMessage

DB_PATH = Path(__file__).resolve().parent / "relaygo.db"

_CREATE_REPORTS = """
CREATE TABLE IF NOT EXISTS reports (
    id         TEXT PRIMARY KEY,
    ts         INTEGER NOT NULL,
    lat        REAL    NOT NULL,
    lng        REAL    NOT NULL,
    acc        REAL    NOT NULL DEFAULT 0,
    type       TEXT    NOT NULL,
    urg        INTEGER NOT NULL,
    haz        TEXT    NOT NULL DEFAULT '[]',
    desc       TEXT    NOT NULL DEFAULT '',
    src        TEXT    NOT NULL DEFAULT '',
    hops       INTEGER NOT NULL DEFAULT 0,
    ttl        INTEGER NOT NULL DEFAULT 5,
    relay_path TEXT    NOT NULL DEFAULT '[]'
);
"""

_CREATE_MESSAGES = """
CREATE TABLE IF NOT EXISTS messages (
    id    TEXT PRIMARY KEY,
    ts    INTEGER NOT NULL,
    src   TEXT    NOT NULL DEFAULT '',
    name  TEXT    NOT NULL DEFAULT '',
    "to"  TEXT,
    body  TEXT    NOT NULL DEFAULT '',
    hops  INTEGER NOT NULL DEFAULT 0,
    ttl   INTEGER NOT NULL DEFAULT 5
);
"""


_CREATE_DIRECTIVES = """
CREATE TABLE IF NOT EXISTS directives (
    id        TEXT PRIMARY KEY,
    ts        INTEGER NOT NULL,
    src       TEXT    NOT NULL DEFAULT '',
    name      TEXT    NOT NULL DEFAULT '',
    "to"      TEXT,
    body      TEXT    NOT NULL DEFAULT '',
    priority  TEXT    NOT NULL DEFAULT 'high',
    hops      INTEGER NOT NULL DEFAULT 0,
    ttl       INTEGER NOT NULL DEFAULT 15,
    fetched_count INTEGER NOT NULL DEFAULT 0
);
"""


async def _get_db() -> aiosqlite.Connection:
    db = await aiosqlite.connect(str(DB_PATH))
    db.row_factory = aiosqlite.Row
    return db


async def init_db() -> None:
    """Create tables if they do not exist."""
    db = await _get_db()
    try:
        await db.execute(_CREATE_REPORTS)
        await db.execute(_CREATE_MESSAGES)
        await db.execute(_CREATE_DIRECTIVES)
        await db.commit()
    finally:
        await db.close()


async def insert_report(report: EmergencyReport) -> bool:
    """Insert a report. Returns True if a new row was created (not a dup)."""
    db = await _get_db()
    try:
        cursor = await db.execute(
            """INSERT OR IGNORE INTO reports
               (id, ts, lat, lng, acc, type, urg, haz, desc, src, hops, ttl, relay_path)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                report.id,
                report.ts,
                report.loc.lat,
                report.loc.lng,
                report.loc.acc,
                report.type,
                report.urg,
                json.dumps(report.haz),
                report.desc,
                report.src,
                report.hops,
                report.ttl,
                json.dumps([p.model_dump() for p in report.relay_path]),
            ),
        )
        await db.commit()
        return cursor.rowcount > 0
    finally:
        await db.close()


async def insert_message(msg: MeshMessage) -> bool:
    """Insert a message. Returns True if a new row was created (not a dup)."""
    db = await _get_db()
    try:
        cursor = await db.execute(
            """INSERT OR IGNORE INTO messages
               (id, ts, src, name, "to", body, hops, ttl)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                msg.id,
                msg.ts,
                msg.src,
                msg.name,
                msg.to,
                msg.body,
                msg.hops,
                msg.ttl,
            ),
        )
        await db.commit()
        return cursor.rowcount > 0
    finally:
        await db.close()


async def insert_directive(directive: Directive) -> bool:
    """Insert a directive. Returns True if a new row was created."""
    db = await _get_db()
    try:
        cursor = await db.execute(
            """INSERT OR IGNORE INTO directives
               (id, ts, src, name, "to", body, priority, hops, ttl)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                directive.id,
                directive.ts,
                directive.src,
                directive.name,
                directive.to,
                directive.body,
                directive.priority,
                directive.hops,
                directive.ttl,
            ),
        )
        await db.commit()
        return cursor.rowcount > 0
    finally:
        await db.close()


async def get_directives(limit: int = 100) -> list[dict[str, Any]]:
    """Return all directives."""
    db = await _get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM directives ORDER BY ts DESC LIMIT ?", (limit,)
        )
        rows = await cursor.fetchall()
        results: list[dict[str, Any]] = []
        for row in rows:
            d = dict(row)
            d["kind"] = "directive"
            results.append(d)
        return results
    finally:
        await db.close()


async def get_pending_directives() -> list[dict[str, Any]]:
    """Return directives not yet fetched by mobile gateways, and bump their fetch count."""
    db = await _get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM directives WHERE fetched_count = 0 ORDER BY ts ASC"
        )
        rows = await cursor.fetchall()
        results: list[dict[str, Any]] = []
        ids: list[str] = []
        for row in rows:
            d = dict(row)
            d["kind"] = "directive"
            results.append(d)
            ids.append(d["id"])
        if ids:
            placeholders = ",".join("?" for _ in ids)
            await db.execute(
                f"UPDATE directives SET fetched_count = fetched_count + 1 WHERE id IN ({placeholders})",
                ids,
            )
            await db.commit()
        return results
    finally:
        await db.close()


async def get_reports(limit: int = 100) -> list[dict[str, Any]]:
    """Return the most recent reports as dicts."""
    db = await _get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM reports ORDER BY ts DESC LIMIT ?", (limit,)
        )
        rows = await cursor.fetchall()
        results: list[dict[str, Any]] = []
        for row in rows:
            d = dict(row)
            d["haz"] = json.loads(d["haz"])
            d["relay_path"] = json.loads(d.get("relay_path") or "[]")
            # Nest location back into the shape the frontend expects.
            d["loc"] = {"lat": d.pop("lat"), "lng": d.pop("lng"), "acc": d.pop("acc")}
            d["kind"] = "report"
            results.append(d)
        return results
    finally:
        await db.close()


async def get_reports_geojson() -> dict[str, Any]:
    """Return all reports as a GeoJSON FeatureCollection."""
    db = await _get_db()
    try:
        cursor = await db.execute("SELECT * FROM reports ORDER BY ts DESC")
        rows = await cursor.fetchall()
        features: list[dict[str, Any]] = []
        for row in rows:
            d = dict(row)
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [d["lng"], d["lat"]],
                },
                "properties": {
                    "id": d["id"],
                    "ts": d["ts"],
                    "type": d["type"],
                    "urg": d["urg"],
                    "haz": json.loads(d["haz"]),
                    "desc": d["desc"],
                    "src": d["src"],
                    "hops": d["hops"],
                    "relay_path": json.loads(d.get("relay_path") or "[]"),
                },
            }
            features.append(feature)
        return {"type": "FeatureCollection", "features": features}
    finally:
        await db.close()
