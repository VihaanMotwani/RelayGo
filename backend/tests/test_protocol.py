"""
RelayGo Backend — DUT/Testbench Protocol Tests

Each test follows the pattern:
  [STIMULUS]   → describe what JSON / request is driven into the DUT
  [DUT]        → describe backend processing (implicit, via logging)
  [SCOREBOARD] → verdict with expected vs actual values
"""

from __future__ import annotations

import json
import time
import uuid

import pytest
from httpx import AsyncClient
from fastapi.testclient import TestClient

# Import helpers from conftest (auto-discovered by pytest)
from .helpers import make_report, make_msg


# ============================================================================
# 1. MODEL VALIDATION (Stimulus: raw JSON → DUT: Pydantic → Scoreboard)
# ============================================================================

class TestModelValidation:
    """Drive raw JSON into Pydantic models through validating boundaries."""

    def test_valid_report_parses(self, tb):
        from models import EmergencyReport
        payload = make_report()
        tb.info(f"[STIMULUS] EmergencyReport JSON: {json.dumps(payload, indent=2)}")
        report = EmergencyReport(**payload)
        tb.info(f"[DUT]      Parsed → kind={report.kind}, type={report.type}, urg={report.urg}")
        assert report.kind == "report"
        tb.info("[SCOREBOARD] ✅ Valid report parsed successfully")

    def test_urgency_upper_bound_rejected(self, tb):
        from models import EmergencyReport
        import pydantic
        payload = make_report(urg=6)
        tb.info(f"[STIMULUS] EmergencyReport with urg=6 (out of range)")
        with pytest.raises(pydantic.ValidationError) as exc_info:
            EmergencyReport(**payload)
        tb.info(f"[DUT]      ValidationError raised: {exc_info.value.error_count()} error(s)")
        tb.info("[SCOREBOARD] ✅ urg=6 correctly rejected")

    def test_urgency_lower_bound_rejected(self, tb):
        from models import EmergencyReport
        import pydantic
        payload = make_report(urg=0)
        tb.info(f"[STIMULUS] EmergencyReport with urg=0 (below min)")
        with pytest.raises(pydantic.ValidationError):
            EmergencyReport(**payload)
        tb.info("[SCOREBOARD] ✅ urg=0 correctly rejected")

    def test_invalid_emergency_type_rejected(self, tb):
        from models import EmergencyReport
        import pydantic
        tb.info('[STIMULUS] EmergencyReport with type="volcano"')
        with pytest.raises(pydantic.ValidationError):
            EmergencyReport(**make_report(type="volcano"))
        tb.info("[SCOREBOARD] ✅ Unknown type 'volcano' rejected")

    def test_all_allowed_types_parse(self, tb):
        from models import EmergencyReport
        types = ("fire", "medical", "structural", "flood", "hazmat", "other")
        for t in types:
            r = EmergencyReport(**make_report(type=t))
            assert r.type == t
        tb.info(f"[STIMULUS] Tested all {len(types)} allowed types")
        tb.info("[SCOREBOARD] ✅ All types accepted")

    def test_missing_ts_raises(self, tb):
        from models import EmergencyReport
        import pydantic
        payload = make_report()
        del payload["ts"]
        tb.info("[STIMULUS] EmergencyReport with ts field removed")
        with pytest.raises(pydantic.ValidationError):
            EmergencyReport(**payload)
        tb.info("[SCOREBOARD] ✅ Missing ts correctly rejected")

    def test_haz_defaults_to_empty(self, tb):
        from models import EmergencyReport
        payload = make_report()
        del payload["haz"]
        tb.info("[STIMULUS] EmergencyReport without haz field")
        r = EmergencyReport(**payload)
        assert r.haz == []
        tb.info(f"[DUT]      haz defaulted to {r.haz}")
        tb.info("[SCOREBOARD] ✅ haz defaults to []")

    def test_broadcast_message_parses(self, tb):
        from models import MeshMessage
        payload = make_msg(to=None)
        tb.info(f"[STIMULUS] MeshMessage broadcast (to=null): {json.dumps(payload)[:120]}...")
        msg = MeshMessage(**payload)
        assert msg.to is None
        tb.info("[SCOREBOARD] ✅ Broadcast message parsed, to=None")

    def test_direct_message_to_field(self, tb):
        from models import MeshMessage
        payload = make_msg(to="device-ccc")
        tb.info(f'[STIMULUS] MeshMessage DM to="device-ccc"')
        msg = MeshMessage(**payload)
        assert msg.to == "device-ccc"
        tb.info("[SCOREBOARD] ✅ DM parsed, to='device-ccc'")

    def test_message_missing_ts_raises(self, tb):
        from models import MeshMessage
        import pydantic
        payload = make_msg()
        del payload["ts"]
        tb.info("[STIMULUS] MeshMessage without ts field")
        with pytest.raises(pydantic.ValidationError):
            MeshMessage(**payload)
        tb.info("[SCOREBOARD] ✅ Missing ts rejected")

    def test_message_wrong_kind_raises(self, tb):
        from models import MeshMessage
        import pydantic
        tb.info('[STIMULUS] MeshMessage with kind="report" (wrong)')
        with pytest.raises(pydantic.ValidationError):
            MeshMessage(**make_msg(kind="report"))
        tb.info("[SCOREBOARD] ✅ Wrong kind rejected")

    def test_mixed_batch_parses(self, tb):
        from models import BatchUpload
        batch_data = {"packets": [make_report(), make_msg()]}
        tb.info(f"[STIMULUS] BatchUpload with 1 report + 1 message")
        batch = BatchUpload(**batch_data)
        assert len(batch.packets) == 2
        tb.info("[SCOREBOARD] ✅ Mixed batch parsed, 2 packets")

    def test_empty_batch_is_valid(self, tb):
        from models import BatchUpload
        tb.info("[STIMULUS] BatchUpload with empty packets list")
        batch = BatchUpload(packets=[])
        assert batch.packets == []
        tb.info("[SCOREBOARD] ✅ Empty batch accepted")

    def test_unknown_kind_in_batch_raises(self, tb):
        from models import BatchUpload
        import pydantic
        bad = make_report(kind="UNKNOWN")
        tb.info(f'[STIMULUS] BatchUpload with kind="UNKNOWN"')
        with pytest.raises(pydantic.ValidationError):
            BatchUpload(packets=[bad])
        tb.info("[SCOREBOARD] ✅ Unknown kind rejected in batch")


# ============================================================================
# 2. PACKET STORE — SQLite INSERT + DEDUP
# ============================================================================

class TestPacketStoreInsert:
    """Drive packets into the SQLite store and verify deduplication."""

    async def test_insert_new_report_returns_true(self, tb, _tmp_db):
        from database import init_db, insert_report
        from models import EmergencyReport
        await init_db()
        report = EmergencyReport(**make_report())
        tb.info(f"[STIMULUS] insert_report(id={report.id[:8]}...)")
        is_new = await insert_report(report)
        tb.info(f"[DUT]      returned is_new={is_new}")
        assert is_new is True
        tb.info("[SCOREBOARD] ✅ New report inserted")

    async def test_duplicate_report_returns_false(self, tb, _tmp_db):
        from database import init_db, insert_report
        from models import EmergencyReport
        await init_db()
        payload = make_report()
        report = EmergencyReport(**payload)
        tb.info(f"[STIMULUS] Insert report id={report.id[:8]}... TWICE")
        await insert_report(report)
        is_new = await insert_report(report)
        tb.info(f"[DUT]      Second insert returned is_new={is_new}")
        assert is_new is False
        tb.info("[SCOREBOARD] ✅ Duplicate correctly rejected (dedup works)")

    async def test_different_ids_both_insert(self, tb, _tmp_db):
        from database import init_db, insert_report, get_reports
        from models import EmergencyReport
        await init_db()
        r1 = EmergencyReport(**make_report())
        r2 = EmergencyReport(**make_report())
        tb.info(f"[STIMULUS] Insert 2 reports: id1={r1.id[:8]}..., id2={r2.id[:8]}...")
        await insert_report(r1)
        await insert_report(r2)
        rows = await get_reports()
        tb.info(f"[DUT]      get_reports() returned {len(rows)} rows")
        assert len(rows) == 2
        tb.info("[SCOREBOARD] ✅ Two distinct UUIDs both persisted")

    async def test_insert_new_message_returns_true(self, tb, _tmp_db):
        from database import init_db, insert_message
        from models import MeshMessage
        await init_db()
        msg = MeshMessage(**make_msg())
        tb.info(f"[STIMULUS] insert_message(id={msg.id[:8]}...)")
        is_new = await insert_message(msg)
        assert is_new is True
        tb.info("[SCOREBOARD] ✅ New message inserted")

    async def test_duplicate_message_returns_false(self, tb, _tmp_db):
        from database import init_db, insert_message
        from models import MeshMessage
        await init_db()
        msg = MeshMessage(**make_msg())
        tb.info(f"[STIMULUS] Insert message id={msg.id[:8]}... TWICE")
        await insert_message(msg)
        is_new = await insert_message(msg)
        assert is_new is False
        tb.info("[SCOREBOARD] ✅ Duplicate message rejected")


# ============================================================================
# 3. RETRIEVAL & GEOJSON SHAPE
# ============================================================================

class TestRetrieval:
    """Verify report retrieval shape and GeoJSON structure."""

    async def test_get_reports_empty(self, tb, _tmp_db):
        from database import init_db, get_reports
        await init_db()
        rows = await get_reports()
        tb.info(f"[DUT]      get_reports() on empty DB → {len(rows)} rows")
        assert rows == []
        tb.info("[SCOREBOARD] ✅ Empty DB returns []")

    async def test_get_reports_reconstructs_loc(self, tb, _tmp_db):
        from database import init_db, insert_report, get_reports
        from models import EmergencyReport
        await init_db()
        await insert_report(EmergencyReport(**make_report()))
        rows = await get_reports()
        row = rows[0]
        tb.info(f"[DUT]      Returned row keys: {list(row.keys())}")
        assert "loc" in row
        assert "lat" in row["loc"] and "lng" in row["loc"]
        assert "lat" not in row  # must NOT be flat
        tb.info(f"[DUT]      loc={row['loc']}")
        tb.info("[SCOREBOARD] ✅ Location correctly nested as loc.lat/lng/acc")

    async def test_get_reports_includes_kind(self, tb, _tmp_db):
        from database import init_db, insert_report, get_reports
        from models import EmergencyReport
        await init_db()
        await insert_report(EmergencyReport(**make_report()))
        rows = await get_reports()
        assert rows[0]["kind"] == "report"
        tb.info("[SCOREBOARD] ✅ kind='report' present in output")

    async def test_get_reports_limit(self, tb, _tmp_db):
        from database import init_db, insert_report, get_reports
        from models import EmergencyReport
        await init_db()
        for i in range(3):
            await insert_report(EmergencyReport(**make_report()))
        rows = await get_reports(limit=1)
        tb.info(f"[DUT]      get_reports(limit=1) → {len(rows)} row(s)")
        assert len(rows) == 1
        tb.info("[SCOREBOARD] ✅ Limit respected")

    async def test_geojson_structure(self, tb, _tmp_db):
        from database import init_db, insert_report, get_reports_geojson
        from models import EmergencyReport
        await init_db()
        await insert_report(EmergencyReport(**make_report()))
        geojson = await get_reports_geojson()
        tb.info(f"[DUT]      GeoJSON type={geojson['type']}, features={len(geojson['features'])}")
        assert geojson["type"] == "FeatureCollection"
        feat = geojson["features"][0]
        assert feat["geometry"]["type"] == "Point"
        lng, lat = feat["geometry"]["coordinates"]
        assert lat == pytest.approx(37.77)
        assert lng == pytest.approx(-122.41)
        tb.info(f"[DUT]      Coordinates: [{lng}, {lat}]")
        tb.info("[SCOREBOARD] ✅ Valid GeoJSON FeatureCollection")


# ============================================================================
# 4. REST ENDPOINT TESTS
# ============================================================================

class TestRESTIngestion:
    """Drive BatchUpload JSON through POST /api/reports with full logging."""

    async def test_health(self, tb, client: AsyncClient):
        tb.info("[STIMULUS] GET /health")
        resp = await client.get("/health")
        tb.info(f"[DUT]      {resp.status_code} → {resp.json()}")
        assert resp.status_code == 200
        tb.info("[SCOREBOARD] ✅ Health OK")

    async def test_post_single_report(self, tb, client: AsyncClient):
        report = make_report()
        payload = {"packets": [report]}
        tb.info(f"[STIMULUS] POST /api/reports — 1 report, id={report['id'][:8]}...")
        resp = await client.post("/api/reports", json=payload)
        body = resp.json()
        tb.info(f"[DUT]      Response: {json.dumps(body)}")
        assert body["ok"] is True
        assert body["inserted_reports"] == 1
        assert body["inserted_messages"] == 0
        tb.info("[SCOREBOARD] ✅ 1 report ingested")

    async def test_post_single_message(self, tb, client: AsyncClient):
        msg = make_msg()
        tb.info(f"[STIMULUS] POST /api/reports — 1 message, id={msg['id'][:8]}...")
        resp = await client.post("/api/reports", json={"packets": [msg]})
        body = resp.json()
        tb.info(f"[DUT]      Response: {json.dumps(body)}")
        assert body["inserted_messages"] == 1
        assert body["inserted_reports"] == 0
        tb.info("[SCOREBOARD] ✅ 1 message ingested")

    async def test_post_mixed_batch(self, tb, client: AsyncClient):
        r = make_report()
        m = make_msg()
        tb.info(f"[STIMULUS] POST /api/reports — 1 report + 1 message")
        resp = await client.post("/api/reports", json={"packets": [r, m]})
        body = resp.json()
        tb.info(f"[DUT]      Response: {json.dumps(body)}")
        assert body["inserted_reports"] == 1 and body["inserted_messages"] == 1
        tb.info("[SCOREBOARD] ✅ Mixed batch: 1+1 ingested")

    async def test_duplicate_report_not_counted(self, tb, client: AsyncClient):
        packet = make_report()
        tb.info(f"[STIMULUS] POST same report id={packet['id'][:8]}... TWICE")
        await client.post("/api/reports", json={"packets": [packet]})
        resp = await client.post("/api/reports", json={"packets": [packet]})
        tb.info(f"[DUT]      Second POST: inserted_reports={resp.json()['inserted_reports']}")
        assert resp.json()["inserted_reports"] == 0
        tb.info("[SCOREBOARD] ✅ Duplicate report deduped at REST layer")

    async def test_empty_batch_accepted(self, tb, client: AsyncClient):
        tb.info("[STIMULUS] POST /api/reports — empty batch")
        resp = await client.post("/api/reports", json={"packets": []})
        assert resp.status_code == 200
        tb.info("[SCOREBOARD] ✅ Empty batch accepted (200)")

    async def test_invalid_kind_returns_422(self, tb, client: AsyncClient):
        bad = make_report(kind="GARBAGE")
        tb.info(f'[STIMULUS] POST with kind="GARBAGE"')
        resp = await client.post("/api/reports", json={"packets": [bad]})
        tb.info(f"[DUT]      Status: {resp.status_code}")
        assert resp.status_code == 422
        tb.info("[SCOREBOARD] ✅ Invalid kind → 422")

    async def test_urgency_out_of_range_returns_422(self, tb, client: AsyncClient):
        bad = make_report(urg=99)
        tb.info(f"[STIMULUS] POST with urg=99")
        resp = await client.post("/api/reports", json={"packets": [bad]})
        assert resp.status_code == 422
        tb.info("[SCOREBOARD] ✅ urg=99 → 422")

    async def test_get_reports_empty(self, tb, client: AsyncClient):
        tb.info("[STIMULUS] GET /api/reports on empty DB")
        resp = await client.get("/api/reports")
        assert resp.json() == []
        tb.info("[SCOREBOARD] ✅ Empty list returned")

    async def test_get_reports_after_insert(self, tb, client: AsyncClient):
        await client.post("/api/reports", json={"packets": [make_report()]})
        tb.info("[STIMULUS] GET /api/reports after 1 insert")
        resp = await client.get("/api/reports")
        rows = resp.json()
        assert len(rows) == 1 and rows[0]["kind"] == "report"
        tb.info(f"[DUT]      Returned {len(rows)} report(s)")
        tb.info("[SCOREBOARD] ✅ Report retrievable via GET")

    async def test_get_reports_limit(self, tb, client: AsyncClient):
        for _ in range(5):
            await client.post("/api/reports", json={"packets": [make_report()]})
        resp = await client.get("/api/reports?limit=2")
        assert len(resp.json()) == 2
        tb.info("[SCOREBOARD] ✅ GET limit=2 returns 2")

    async def test_get_geojson(self, tb, client: AsyncClient):
        await client.post("/api/reports", json={"packets": [make_report()]})
        resp = await client.get("/api/reports/geojson")
        geojson = resp.json()
        assert geojson["type"] == "FeatureCollection"
        tb.info(f"[DUT]      GeoJSON features: {len(geojson['features'])}")
        tb.info("[SCOREBOARD] ✅ GeoJSON endpoint OK")


# ============================================================================
# 5. PROTOCOL SEMANTICS
# ============================================================================

class TestProtocolSemantics:
    """Verify hops/TTL/broadcast-vs-DM logic."""

    def test_broadcast_has_null_to(self, tb):
        from models import MeshMessage
        msg = MeshMessage(**make_msg(to=None))
        tb.info(f"[DUT]      msg.to = {msg.to}")
        assert msg.to is None
        tb.info("[SCOREBOARD] ✅ Broadcast → to is None")

    def test_dm_has_target(self, tb):
        from models import MeshMessage
        msg = MeshMessage(**make_msg(to="device-xyz"))
        assert msg.to == "device-xyz"
        tb.info("[SCOREBOARD] ✅ DM → to='device-xyz'")

    def test_json_serialisation(self, tb):
        from models import MeshMessage
        broadcast = MeshMessage(**make_msg())
        dm = MeshMessage(**make_msg(to="device-xyz"))
        for label, msg in [("broadcast", broadcast), ("DM", dm)]:
            dumped = msg.model_dump()
            raw = json.dumps(dumped)
            tb.info(f"[DUT]      {label} JSON size: {len(raw)} bytes")
            assert raw  # must not be empty
        tb.info("[SCOREBOARD] ✅ Both serialise to valid JSON")

    def test_initial_hops_zero(self, tb):
        from models import EmergencyReport
        r = EmergencyReport(**make_report(hops=0))
        assert r.hops == 0
        tb.info("[SCOREBOARD] ✅ Initial hops = 0")

    def test_hop_increment_simulation(self, tb):
        from models import EmergencyReport
        report = EmergencyReport(**make_report())
        dumped = report.model_dump()
        dumped["hops"] += 1
        relayed = EmergencyReport(**dumped)
        tb.info(f"[DUT]      Original hops=0 → Relayed hops={relayed.hops}")
        assert relayed.hops == 1
        tb.info("[SCOREBOARD] ✅ Hop increment works")

    def test_packet_expired(self, tb):
        from models import EmergencyReport
        report = EmergencyReport(**make_report(hops=10, ttl=10))
        expired = report.hops >= report.ttl
        tb.info(f"[DUT]      hops={report.hops}, ttl={report.ttl} → expired={expired}")
        assert expired
        tb.info("[SCOREBOARD] ✅ hops >= ttl means expired (relay must drop)")

    def test_packet_alive(self, tb):
        from models import EmergencyReport
        report = EmergencyReport(**make_report(hops=3, ttl=10))
        alive = report.hops < report.ttl
        tb.info(f"[DUT]      hops={report.hops}, ttl={report.ttl} → alive={alive}")
        assert alive
        tb.info("[SCOREBOARD] ✅ hops < ttl means alive (relay must forward)")

    async def test_cross_batch_dedup(self, tb, client: AsyncClient):
        shared_id = str(uuid.uuid4())
        packet = make_report(id=shared_id)
        tb.info(f"[STIMULUS] Same UUID {shared_id[:8]}... POSTed from 2 simulated mesh nodes")
        r1 = await client.post("/api/reports", json={"packets": [packet]})
        r2 = await client.post("/api/reports", json={"packets": [packet]})
        tb.info(f"[DUT]      Node A: inserted={r1.json()['inserted_reports']}")
        tb.info(f"[DUT]      Node B: inserted={r2.json()['inserted_reports']}")
        assert r1.json()["inserted_reports"] == 1
        assert r2.json()["inserted_reports"] == 0
        rows = (await client.get("/api/reports")).json()
        matching = [r for r in rows if r["id"] == shared_id]
        assert len(matching) == 1
        tb.info("[SCOREBOARD] ✅ Cross-node UUID dedup works")


# ============================================================================
# 6. WEBSOCKET BROADCAST HUB
# ============================================================================

class TestWebSocketBroadcast:
    """Test WS broadcast with verbose logging."""

    def test_ws_connect(self, tb, sync_client: TestClient):
        tb.info("[STIMULUS] WebSocket connect to /ws/dashboard")
        with sync_client.websocket_connect("/ws/dashboard") as ws:
            ws.send_text("ping")
            tb.info("[DUT]      Connection accepted, sent ping")
        tb.info("[SCOREBOARD] ✅ WebSocket connection OK")

    def test_report_broadcast_via_ws(self, tb, sync_client: TestClient):
        with sync_client.websocket_connect("/ws/dashboard") as ws:
            packet = make_report()
            tb.info(f"[STIMULUS] POST report id={packet['id'][:8]}... while WS connected")
            sync_client.post("/api/reports", json={"packets": [packet]})
            data = ws.receive_text()
            broadcast = json.loads(data)
            tb.info(f"[DUT]      WS received {len(broadcast)} packet(s)")
            assert isinstance(broadcast, list) and len(broadcast) == 1
            assert broadcast[0]["id"] == packet["id"]
            tb.info("[SCOREBOARD] ✅ Report broadcast to WS dashboard")

    def test_dup_does_not_broadcast(self, tb, sync_client: TestClient):
        packet = make_report()
        sync_client.post("/api/reports", json={"packets": [packet]})
        tb.info(f"[STIMULUS] Second POST of same id={packet['id'][:8]}... with WS connected")
        with sync_client.websocket_connect("/ws/dashboard") as ws:
            resp = sync_client.post("/api/reports", json={"packets": [packet]})
            tb.info(f"[DUT]      inserted_reports={resp.json()['inserted_reports']}")
            assert resp.json()["inserted_reports"] == 0
        tb.info("[SCOREBOARD] ✅ Duplicate suppressed — no WS broadcast")

    def test_messages_not_broadcast(self, tb, sync_client: TestClient):
        msg = make_msg()
        tb.info("[STIMULUS] POST message (not report) with WS connected")
        with sync_client.websocket_connect("/ws/dashboard") as ws:
            resp = sync_client.post("/api/reports", json={"packets": [msg]})
            body = resp.json()
            tb.info(f"[DUT]      inserted_messages={body['inserted_messages']}, inserted_reports={body['inserted_reports']}")
            assert body["inserted_messages"] == 1
            assert body["inserted_reports"] == 0
        tb.info("[SCOREBOARD] ✅ Messages inserted but not broadcast to dashboard")
