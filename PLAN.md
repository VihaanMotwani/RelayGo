
# RelayGo — Implementation Plan

## Context

Problem: During disasters (earthquakes, hurricanes, fires), cellular networks and power grids fail, leaving people unable to report emergencies or get help. Existing 911 infrastructure is centralized and fragile.

Solution: RelayGo is an offline-first emergency response app that:
1. Uses on-device AI (Cactus Compute) to calm users and provide verified emergency guidance
2. Transcribes voice reports and extracts structured JSON via tool calling
3. Broadcasts tiny JSON packets over a BLE mesh network (phone-to-phone)
4. Enables P2P messaging (broadcast alerts + direct 1-to-1 messages) over the same BLE mesh — no internet needed
5. Provides a Disaster Awareness screen where AI aggregates all incoming mesh data (reports + messages) into a live situational summary with guidance
6. Uploads aggregated data to a backend when any node regains connectivity
7. Visualizes emergency data on a real-time dashboard map

Tech Stack: Flutter (iOS + Android) | Cactus Compute (on-device AI) | Raw BLE mesh | FastAPI (Python backend) | React + Mapbox (dashboard)

---
## Architecture Overview

```text
┌──────────────────────────────────────────────────────────────┐
│                       FLUTTER APP                            │
│                                                              │
│  ┌──────────┐  ┌───────────┐  ┌───────────────────────────┐  │
│  │  Voice   │→ │  Cactus   │→ │  Tool Calling             │  │
│  │ Record   │  │  Whisper  │  │  extract_emergency()      │  │
│  └──────────┘  │  (STT)    │  │  → structured JSON packet │  │
│                └───────────┘  └────────────┬──────────────┘  │
│  ┌──────────┐  ┌───────────┐               │                 │
│  │  Text    │→ │  Cactus   │               ▼                 │
│  │  Input   │  │  LLM+RAG  │  ┌────────────────────────┐     │
│  └──────────┘  │  (Chat)   │  │  BLE Mesh Service      │     │
│                └───────────┘  │  Peripheral + Central  │     │
│                               │  Reports + Messages    │     │
│  ┌───────────────────────┐    │  Store & Forward       │     │
│  │  P2P Messaging        │───→│                        │     │
│  │  Broadcast + Direct   │←───│                        │     │
│  └───────────────────────┘    └────────────┬───────────┘     │
│                                            │                 │
│  ┌───────────────────────┐    ┌────────────▼───────────┐     │
│  │  Disaster Awareness   │    │  Backend Sync          │     │
│  │  AI aggregates mesh   │    │  (when online)         │     │
│  │  data → live summary  │    └────────────┬───────────┘     │
│  │  + guidance           │                 │                 │
│  └───────────────────────┘                 │                 │
└────────────────────────────────────────────┼─────────────────┘
                                             │
                      ┌──────────────────────▼──────────────┐
                      │          FastAPI Backend             │
                      │  POST /api/reports (batch)           │
                      │  WebSocket /ws/dashboard             │
                      └──────────────────────┬──────────────┘
                                             │
                      ┌──────────────────────▼──────────────┐
                      │      React + Mapbox Dashboard        │
                      │  Real-time emergency map             │
                      │  Color-coded by type + urgency       │
                      └─────────────────────────────────────┘
```

---
## Mesh Packet Formats

The BLE mesh carries two packet types, distinguished by a kind field.

### Emergency Report Packet (~200-400 bytes)

```json
{
  "kind": "report",
  "id": "uuid-v4",
  "ts": 1709337600,
  "loc": {"lat": 37.77, "lng": -122.41, "acc": 10},
  "type": "fire|medical|structural|flood|hazmat|other",
  "urg": 3,
  "haz": ["gas_leak"],
  "desc": "Compressed 1-sentence summary",
  "src": "device-fingerprint",
  "hops": 0,
  "ttl": 10
}
```

### Message Packet (~100-300 bytes)

```json
{
  "kind": "msg",
  "id": "uuid-v4",
  "ts": 1709337600,
  "src": "device-fingerprint",
  "name": "User display name",
  "to": null,
  "body": "Message text content",
  "hops": 0,
  "ttl": 10
}
```
- to: null = broadcast (visible to everyone on the mesh)
- to: "device-fingerprint" = direct message (only rendered on the target device, but relayed through all nodes for reach)

---
## Hallucination Mitigation (6-Layer Defense)

1. RAG retrieval — Only verified emergency procedures injected into context
2. Strict system prompt — "Say 'I don't have verified info' when uncertain. NEVER fabricate medical advice."
3. Low temperature (0.3) — Reduces creative/hallucinated output
4. Tool calling — Forces structured extraction (enum types, bounded urgency 1-5)
5. Response tagging — UI shows [VERIFIED PROCEDURE] / [MESH REPORT] / [UNVERIFIED] badges
6. Live situational awareness — Mesh packets feed into RAG so AI can reference actual reported conditions
7. Template-only critical info — First aid procedures are retrieved verbatim from knowledge base, never generated

---
## Project Structure

```text RelayGo/
├── app/                              # Flutter mobile app
│   ├── pubspec.yaml
│   ├── android/
│   │   └── app/src/main/AndroidManifest.xml
│   ├── ios/
│   │   └── Runner/Info.plist
│   ├── assets/
│   │   └── knowledge/                # RAG knowledge base
│   │       ├── first_aid_basics.txt
│   │       ├── cpr_instructions.txt
│   │       ├── fire_evacuation.txt
│   │       ├── flood_response.txt
│   │       ├── hazmat_safety.txt
│   │       ├── earthquake_response.txt
│   │       └── general_emergency.txt
│   └── lib/
│       ├── main.dart                 # Entry, MultiProvider setup
│       ├── app.dart                  # MaterialApp, routing, theme
│       ├── core/
│       │   ├── constants.dart        # BLE UUIDs, model slugs, backend URL
│       │   ├── theme.dart            # Emergency dark theme
│       │   └── permissions.dart      # Runtime permission helper
│       ├── models/
│       │   ├── emergency_report.dart # Report packet data class + serialization
│       │   ├── mesh_message.dart     # Message packet data class (broadcast + DM)
│       │   ├── mesh_packet.dart      # Union type: report | message, shared serialization
│       │   ├── chat_message.dart     # AI chat message with role, confidence
│       │   └── peer_info.dart        # BLE peer: device ID, display name, last seen
│       ├── services/
│       │   ├── ai/
│       │   │   ├── ai_service.dart       # Orchestrator: STT + LLM + RAG
│       │   │   ├── prompts.dart          # System prompt + tool definitions
│       │   │   ├── knowledge_loader.dart # Load txt files into RAG corpus
│       │   │   └── awareness_service.dart # Aggregates mesh data → AI situational summary
│       │   ├── mesh/
│       │   │   ├── mesh_service.dart      # High-level mesh orchestrator
│       │   │   ├── ble_central.dart       # flutter_blue_plus: scan + write packets
│       │   │   ├── ble_peripheral.dart    # ble_peripheral: advertise + receive
│       │   │   └── packet_store.dart      # SQLite dedup + storage (reports + messages)
│       │   ├── location_service.dart      # GPS via geolocator
│       │   ├── audio_service.dart         # Mic recording via record package
│       │   └── backend_sync.dart          # HTTP batch upload when online
│       ├── providers/
│       │   ├── ai_provider.dart           # AI init state, progress
│       │   ├── chat_provider.dart         # AI chat flow orchestration
│       │   ├── messaging_provider.dart    # P2P messaging state (broadcast + DM)
│       │   ├── awareness_provider.dart    # Disaster awareness summary state
│       │   ├── mesh_provider.dart         # Mesh state, peer count
│       │   └── connectivity_provider.dart # Online/offline detection
│       └── ui/
│           ├── screens/
│           │   ├── home_screen.dart       # SOS button, status, quick actions
│           │   ├── chat_screen.dart       # AI assistant chat interface
│           │   ├── messaging_screen.dart  # P2P messaging: broadcast feed + DM threads
│           │   ├── conversation_screen.dart # Individual DM conversation
│           │   ├── awareness_screen.dart  # Disaster Awareness: AI-generated live summary
│           │   ├── reports_screen.dart    # Mesh-received reports list
│           │   └── loading_screen.dart    # Model download progress
│           └── widgets/
│               ├── sos_button.dart        # Animated pulsing SOS button
│               ├── chat_bubble.dart       # Message bubble with confidence
│               ├── message_bubble.dart    # P2P message bubble (simpler, no confidence)
│               ├── recording_indicator.dart
│               ├── mesh_status_bar.dart   # Peer count + connectivity
│               ├── report_card.dart       # Emergency report card
│               ├── awareness_card.dart    # Situational update card
│               └── confidence_badge.dart  # [Verified]/[Uncertain] badge
│
├── backend/                          # Python FastAPI
│   ├── requirements.txt              # fastapi, uvicorn, pydantic, websockets, aiosqlite
│   ├── main.py                       # App entry, CORS, startup
│   ├── models.py                     # Pydantic: EmergencyReport, BatchUpload, Location
│   ├── database.py                   # SQLite: init, insert (dedup), query, geojson
│   └── routes/
│       ├── reports.py                # POST /api/reports, GET /api/reports, GET /api/reports/geojson
│       └── websocket.py              # WebSocket /ws/dashboard broadcast hub
│
├── dashboard/                        # React + Mapbox
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   └── src/
│       ├── main.jsx
│       ├── App.jsx                   # Layout: StatsBar + Map + ReportList
│       ├── components/
│       │   ├── Map.jsx               # Mapbox GL: markers, clustering, popups
│       │   ├── ReportList.jsx        # Sidebar sorted by urgency/time
│       │   ├── ReportCard.jsx        # Report detail card
│       │   ├── StatsBar.jsx          # Total reports, type breakdown, avg hops
│       │   └── Legend.jsx            # Color/icon legend
│       ├── hooks/
│       │   └── useWebSocket.js       # WS with reconnect + REST initial load
│       └── utils/
│           └── mapStyles.js          # Color mapping, clustering config
│
└── docs/
    └── ARCHITECTURE.md
```

---
## Implementation Phases (Build Order)

Build order is optimized for "demo-able at every checkpoint."

### Phase 0: Scaffolding (15 min)

- flutter create app inside RelayGo/
- mkdir -p backend/routes + scaffold FastAPI files
- npm create vite@latest dashboard -- --template react
- Add all Flutter dependencies to pubspec.yaml:
  - cactus, flutter_blue_plus, ble_peripheral, record, geolocator, sqflite, path_provider, http, uuid, provider, permission_handler, connectivity_plus
- Configure platform permissions (BLE, location, mic, internet)
- Write 7 knowledge base text files (200-500 words each, curated emergency procedures)
- Verify: All three projects run without errors

### Phase 1: Data Model + Storage (30 min)

- emergency_report.dart — Packet class with toJson(), fromJson(), toBytes(), fromBytes()
- packet_store.dart — SQLite table: packets(id TEXT PK, json_data TEXT, received_at INT, uploaded INT DEFAULT 0). Methods: insertIfNew(), getAll(), getUnuploaded(), markUploaded()
- constants.dart — BLE UUIDs, model slugs, emergency types enum
- Verify: Unit tests pass for JSON round-trip, byte encoding, deduplication

### Phase 2: Backend API (45 min)

- models.py — Pydantic models matching packet format
- database.py — SQLite with INSERT OR IGNORE dedup
- routes/reports.py — POST /api/reports (batch), GET /api/reports, GET /api/reports/geojson
- routes/websocket.py — WebSocket hub that broadcasts new reports to connected dashboard clients
- main.py — FastAPI app with CORS, startup DB init
- Verify: Swagger UI works, POST/GET reports via curl, WebSocket broadcasts

### Phase 3: Dashboard (45 min)

- useWebSocket.js — Connect to WS, auto-reconnect, load initial reports via REST
- Map.jsx — Mapbox GL with GeoJSON source, circle layer colored by type (fire=red, medical=blue, structural=orange, flood=cyan, hazmat=purple), radius by urgency. Clustering. Popup on click.
- ReportList.jsx — Sidebar sorted by timestamp desc
- StatsBar.jsx — Total reports, type breakdown, average hops
- App.jsx — Dark theme layout: stats top, map 70%, sidebar 30%
- Verify: POST test reports via curl → markers appear on map in real-time

### Phase 4: AI Service Layer (60 min)

- prompts.dart — System prompt with hallucination rules + extract_emergency tool definition with parameters: type (enum), urgency (1-5), hazards (comma-sep), description (1 sentence)
- knowledge_loader.dart — Load txt files from assets into Cactus RAG corpus
- ai_service.dart — Orchestrator using unified Cactus class:
  - Cactus.create(modelPath, corpusDir: knowledgePath) for LLM + RAG
  - model.transcribe(audioPath) for STT
  - model.completeMessages(messages, tools: tools) for chat + extraction
  - Pipeline: user text → RAG context retrieval → inject into system prompt → LLM chat with tools → parse result.functionCalls → return response + optional extracted report
- Verify: On-device: "There's a fire in my building" → calm response + tool call extracting {type: "fire", urg: 5, haz: ["fire_spread"]}

### Phase 5: BLE Mesh (75 min)

Critical insight: Need BOTH Central + Peripheral roles simultaneously.
- ble_peripheral.dart — Uses ble_peripheral package. Advertises GATT service with writable characteristic. On write: parse packet, increment hops, check TTL, dedup via PacketStore, emit to stream.
- ble_central.dart — Uses flutter_blue_plus. Scans for RelayGo service UUID. On discovery: connect, discover services, write all local packets to peer's characteristic. 30-second periodic scan cycle.
- mesh_service.dart — Starts both roles. Exposes broadcastReport() and Stream<EmergencyReport> onNewPacket. Manages lifecycle.
- backend_sync.dart — Checks connectivity every 15s. When online: batch-upload unuploaded packets to FastAPI.
- Verify: Two physical phones: Device A creates report → BLE sync → Device B receives. Device B gets WiFi → report appears on dashboard.

### Phase 6: Flutter UI (60 min)

- audio_service.dart — Record to WAV at 16kHz mono via record package
- chat_provider.dart — Orchestrates: SOS trigger → voice/text input → transcription → AI pipeline → broadcast extracted report to mesh → update UI
- home_screen.dart — MeshStatusBar top, large animated SOS button center, quick actions bottom
- chat_screen.dart — Message list with ConfidenceBadge per AI message, text input + mic button
- reports_screen.dart — List of ReportCards from mesh, sorted by urgency
- loading_screen.dart — Model download progress bars
- Widgets: sos_button.dart (pulsing red, 200x200), chat_bubble.dart, confidence_badge.dart
- Verify: Full app flow on device

### Phase 7: P2P Messaging (60 min)

Goal: Users can send broadcast alerts and direct messages over the BLE mesh without internet.

- mesh_message.dart — Message packet model with kind: "msg", to field (null=broadcast, device ID=DM), name (sender display name), body (text content). Same toJson/fromJson/toBytes/fromBytes pattern as emergency reports.
- mesh_packet.dart — Union type that deserializes either packet based on kind field. PacketStore updated to handle both types in a single packets table with a kind column.
- messaging_provider.dart — Manages two views:
  - Broadcast feed: All messages where to == null, sorted by timestamp. Like a public bulletin board.
  - DM threads: Messages grouped by peer src field. Only messages where to == myDeviceId or src == myDeviceId.
  - Exposes sendBroadcast(text) and sendDirectMessage(peerId, text) which create message packets and push to mesh.
- messaging_screen.dart — Two tabs: "Broadcast" (public feed) and "Direct" (list of DM threads with peer names). Broadcast tab has a text input to post public alerts. DM thread list shows latest message preview + unread count.
- conversation_screen.dart — Individual DM thread. Simple chat UI with message bubbles. Text input at bottom.
- message_bubble.dart — Simpler than AI chat bubble. Shows sender name, message text, timestamp, hop count badge.
- Update home_screen.dart to add "Messages" quick action button alongside SOS and Chat.
- Update mesh_service.dart and BLE central/peripheral to handle both packet types.
- Verify: Device A sends broadcast "Road blocked on 5th St" → appears on Device B's broadcast feed. Device A sends DM to Device B → appears in Device B's DM thread.

### Phase 8: Disaster Awareness Screen (45 min)

Goal: AI aggregates all mesh data (reports + broadcast messages) into a live situational summary.

- awareness_service.dart — Periodically (or on-demand) feeds all recent reports + broadcast messages into the LLM with a special aggregation prompt:
"You are analyzing emergency data from a mesh network. Summarize the current situation. Report what you know with HIGH confidence based on multiple data points. Flag single-source reports as UNCONFIRMED. Provide actionable guidance: safest routes, areas to avoid, where help is needed. Structure: 1) Situation Overview, 2) Active Threats, 3) Guidance, 4) Areas Needing Help"
- Combines RAG knowledge base (verified procedures) with live mesh data for context-aware guidance.
- awareness_provider.dart — Holds the latest AI-generated situational summary. Refreshes when new reports/messages arrive (debounced to avoid excessive LLM calls, e.g., re-generate at most every 60 seconds).
- awareness_screen.dart — Displays the AI summary in card sections:
  - Situation Overview — "3 fire reports in downtown, 1 medical emergency on east side, flooding on Main St"
  - Active Threats — Color-coded threat cards with urgency
  - Guidance — "Avoid downtown. Nearest safe zone: Central Park. If injured, basic first aid: [link to RAG procedure]"
  - Areas Needing Help — Where reports indicate people need assistance
  - "Last updated X seconds ago" + manual refresh button
  - Each section tagged with [CONFIRMED] (multiple sources) vs [UNCONFIRMED] (single source)
- awareness_card.dart — Card widget for each section of the summary
- Update home_screen.dart to add "Situation" quick action button
- Verify: Create 3-4 varied emergency reports via mesh → open Awareness screen → AI generates coherent situational summary → guidance references RAG knowledge base

### Phase 9: Integration + Polish (30 min)

- Full end-to-end test: speak → transcribe → AI → extract → mesh → P2P messages → awareness screen → backend → dashboard
- Haptic feedback on SOS
- "No internet" banner
- Device fingerprint + user display name setup on first launch (stored in SharedPreferences)
- Dark mode polish
- Unread message badge on home screen

---
## Key Cactus API Usage (from GitHub docs)

```dart
// Initialize model with RAG corpus final model = Cactus.create(modelPath, corpusDir: '/path/to/knowledge');

// Chat completion with tool calling final tools = [
  {'name': 'extract_emergency', 'description': '...', 'parameters': {...}}
];
final result = model.completeMessages(
  [Message.system(systemPrompt), Message.user(userText)],
  tools: tools,
);
// result.text — AI response
// result.functionCalls — [{name: 'extract_emergency', arguments: {...}}]
// result.confidence — 0.0-1.0

// Speech-to-text final transcription = model.transcribe('/path/to/audio.wav');
// transcription.text — transcribed text
```

---
## BLE Mesh Protocol

1. Each phone runs Peripheral (advertise RelayGo service) + Central (scan for peers) simultaneously
2. Central discovers peer → connects → writes all local packets (both reports AND messages) to peer's writable characteristic
3. Peripheral receives packet → parse kind field → increment hops → check hops < ttl → dedup via id → store in appropriate table
4. 30-second scan cycle for continuous discovery
5. Gossip protocol: eventually all nodes converge on same packet set
6. Packet target: <185 bytes (iOS BLE MTU limit)
7. Direct messages (to != null) are relayed through ALL nodes but only rendered on the target device — this ensures reach even when sender and recipient aren't directly connected

---
## Dependencies

Flutter (pubspec.yaml):
- cactus — On-device LLM, STT, RAG, tool calling
- flutter_blue_plus — BLE Central (scan + connect + write)
- ble_peripheral — BLE Peripheral (advertise + receive)
- record — Audio recording to WAV
- geolocator — GPS location
- sqflite + path_provider — Local SQLite storage
- http — Backend HTTP client
- uuid — Packet ID generation
- provider — State management
- permission_handler — Runtime permissions
- connectivity_plus — Online/offline detection

Backend (requirements.txt):
- fastapi, uvicorn, pydantic, websockets, aiosqlite

Dashboard (package.json):
- react, mapbox-gl, vite

---
## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Slow model download at venue | Pre-download models before hackathon |
| BLE flaky on iOS | Test on Android first; demo with two Android phones |
| Small model gives poor responses | RAG + templates as fallback (retrieve-and-display, no generation) |
| Packet > BLE MTU | Keep desc < 80 chars, target < 185 bytes total |
| Mapbox API key needed | Get free token beforehand; Leaflet + OSM as zero-key fallback |

---
## What To Never Cut

1. SOS → speak → transcribe → AI responds → report extracted (this IS the demo)
2. At least one BLE relay between two phones (this IS the mesh differentiator)
3. P2P broadcast message between two phones (proves communication works without internet)
4. Disaster Awareness screen with AI summary (shows the AI is more than a chatbot — it's a live situational intelligence system)
5. Dashboard map showing a report appear in real-time (this IS the wow moment) 
