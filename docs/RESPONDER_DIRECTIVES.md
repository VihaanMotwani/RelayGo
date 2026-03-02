# Responder Directives — Reverse Relay Feature

## Overview

Closes the communication loop: responders on the dashboard can send instructions back through the mesh network to people in the disaster zone.

```
Current (one-way):
  People → BLE Mesh → Gateway Node (has internet) → Backend → Dashboard

New (bidirectional):
  Dashboard → Backend → Gateway Node (has internet) → BLE Mesh → People
```

---

## Packet Format

```json
{
  "kind": "directive",
  "id": "uuid-v4",
  "ts": 1709337600,
  "src": "responder-badge-id",
  "name": "SFPD Dispatch",
  "to": null,
  "body": "Evacuation route open on Market St westbound. Avoid 5th St - gas main rupture.",
  "priority": "high",
  "hops": 0,
  "ttl": 15
}
```

- `priority`: `"high"` | `"medium"` | `"low"` — controls visual urgency on mobile
- `ttl: 15` — higher than normal packets (10) so directives propagate further
- `to: null` — pure broadcast to everyone on the mesh
- `src` — identifier for the responder/agency sending the directive

---

## Component Breakdown

### 1. Backend (Python/FastAPI) — @backend-team

**New model** in `backend/models.py`:
```python
class Directive(BaseModel):
    kind: str = "directive"
    id: str
    ts: int
    src: str
    name: str            # e.g. "SFPD Dispatch", "Fire Captain Rodriguez"
    to: str | None = None
    body: str
    priority: str = "high"  # high | medium | low
    hops: int = 0
    ttl: int = 15
```

**New DB table** in `backend/database.py`:
```sql
CREATE TABLE directives (
    id TEXT PRIMARY KEY,
    json_data TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    fetched_count INTEGER DEFAULT 0
)
```

**New route file** `backend/routes/directives.py`:
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/directives` | POST | Dashboard submits a new directive. Stores in DB, broadcasts to WS clients. |
| `/api/directives` | GET | Returns all directives (for dashboard display). |
| `/api/directives/pending` | GET | Returns directives not yet fetched by mobile. Increments `fetched_count`. Gateway nodes call this during sync. |

**Register the router** in `backend/main.py`.

---

### 2. Dashboard (React/Mapbox) — @vihaan

**New component** `src/components/DirectivePanel.jsx`:
- Input form at the bottom or side of the dashboard
- Fields: responder name, message body, priority dropdown (high/medium/low)
- Submit button → `POST /api/directives` with auto-generated UUID + timestamp
- Visual feedback on send (success toast / error state)

**New component** `src/components/DirectiveList.jsx`:
- List of sent directives, sorted by timestamp desc
- Each directive shows: priority badge, responder name, body text, timestamp
- Visual distinction from reports — use a different accent color (e.g. green or gold border for "official" feel)

**Update** `src/hooks/useWebSocket.js`:
- Listen for incoming `directive` kind on the WebSocket (backend broadcasts new directives to all WS clients)
- Maintain a `directives` state array alongside `reports`

**Update** `src/App.jsx`:
- Add DirectivePanel below the map or as a collapsible panel
- Add DirectiveList as a tab alongside ReportList in the sidebar, or a separate section
- Suggested layout: sidebar has two tabs — "Reports" and "Directives Sent"

**Update** `src/components/StatsBar.jsx`:
- Add directive count to the stats bar

---

### 3. Mobile Sync — @mobile-team

**New model** `app/lib/models/directive.dart`:
- Same pattern as `MeshMessage` — `toJson/fromJson/toBytes/fromBytes`
- Additional `priority` field

**Update** `app/lib/models/mesh_packet.dart`:
- Handle `kind: "directive"` as a third variant in the union type

**Update** `app/lib/services/backend_sync.dart`:
- During each sync cycle, after uploading packets, also call `GET /api/directives/pending`
- For each directive received, wrap as a `MeshPacket` and inject into the mesh via `meshService.broadcastDirective()`
- This is the key bridge: the gateway node pulls from the server and pushes into BLE

**Update** `app/lib/services/mesh/packet_store.dart`:
- Store directives in the same `packets` table with `kind = 'directive'`
- Add `getDirectives()` query method

**Update** `app/lib/services/mesh/mesh_service.dart`:
- Add `broadcastDirective()` method
- Add `onNewDirective` stream

---

### 4. Mobile UI — @mobile-team

**New widget** `app/lib/ui/widgets/directive_banner.dart`:
- Prominent banner with gold/green accent and shield icon
- Shows `OFFICIAL RESPONDER` badge
- Responder name, body text, priority indicator
- Visually distinct from peer messages — this is trusted authority info

**Update** `app/lib/ui/screens/home_screen.dart`:
- If there are unread directives, show the latest directive as a banner above the SOS button
- High priority directives should be impossible to miss

**Update** `app/lib/ui/screens/messaging_screen.dart`:
- Directives appear in the broadcast tab with the OFFICIAL RESPONDER badge
- Sorted above regular broadcast messages

**Update** `app/lib/ui/screens/awareness_screen.dart`:
- AI awareness summary should incorporate directives as HIGH confidence info
- Directives shown as a dedicated "Official Guidance" card at the top

**Update** `app/lib/providers/awareness_provider.dart`:
- Pass directives to the AI summary generation
- Directives are treated as verified/authoritative data

---

## Data Flow Diagram

```
   DASHBOARD                    BACKEND                 GATEWAY NODE              BLE MESH
  (Responder)                                          (has internet)           (disaster zone)
       │                           │                        │                        │
       │  POST /api/directives     │                        │                        │
       │ ────────────────────────> │                        │                        │
       │                           │  store in DB           │                        │
       │                           │  broadcast via WS      │                        │
       │  <──── WS: new directive  │                        │                        │
       │  (confirmation)           │                        │                        │
       │                           │                        │                        │
       │                           │   GET /directives/     │                        │
       │                           │   pending              │                        │
       │                           │ <───────────────────── │  (periodic sync)       │
       │                           │ ─────────────────────> │                        │
       │                           │   [directive JSON]     │                        │
       │                           │                        │                        │
       │                           │                        │  inject into mesh      │
       │                           │                        │ ─────────────────────> │
       │                           │                        │   (BLE gossip          │
       │                           │                        │    propagation)        │
       │                           │                        │                        │
       │                           │                        │              People see │
       │                           │                        │              directive  │
       │                           │                        │              with       │
       │                           │                        │              OFFICIAL   │
       │                           │                        │              badge      │
```

---

## Priority Rendering

| Priority | Mobile Badge Color | Dashboard Color | Behavior |
|----------|--------------------|-----------------|----------|
| `high`   | Red + pulsing      | Red border      | Shows as banner on home screen |
| `medium` | Amber              | Amber border    | Shows in broadcast feed |
| `low`    | Green              | Green border    | Shows in broadcast feed |
