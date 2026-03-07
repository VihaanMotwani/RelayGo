# RelayGo

Offline-first emergency response system that uses Bluetooth Low Energy (BLE) mesh networking to relay emergency reports when internet is unavailable. Includes an on-device AI assistant with RAG-backed knowledge and location awareness, a cloud backend for coordination, and a web dashboard for situational awareness.

---

## Repository Structure

```
RelayGo/
├── app/                  # Flutter mobile app (mesh tester + AI assistant)
├── backend/              # FastAPI backend (REST + WebSocket)
├── dashboard/            # React web dashboard (MapLibre map)
├── data_pipeline/        # Python scripts to build location index
├── simulator/            # Python mesh network simulator
└── ios-native/           # SwiftUI iOS frontend (separate entry point)
```

---

## Mobile App (`app/`)

The primary mobile app lives in `app/lib/mesh_tester/`. It is a Flutter app launched with a dedicated entry point separate from the main Flutter app.

### Running the App

> BLE requires physical devices. Simulators and emulators will not work for mesh testing.

```bash
cd app
flutter pub get

# Run on a physical device
flutter run -d <DEVICE_ID> -t lib/mesh_tester/main_tester.dart
```

To find connected device IDs:
```bash
flutter devices
```

For multi-device BLE testing, run the command on two or more physical devices simultaneously.

### Architecture

The app is structured around a 5-tab shell (`TesterScreen`):

| Tab | Screen | Purpose |
|-----|--------|---------|
| Home | `HomePage` | Mesh controls, emergency report broadcast |
| AI | `AiPage` | On-device AI chat assistant |
| Messages | `MessagesPage` | Peer-to-peer mesh messages |
| Log | `LogPage` | Live debug log |
| Settings | `SettingsPage` | Data management, AI cache, device info |

### Key Services

**Mesh Layer**
- `InstrumentedMeshService` — wraps the production `MeshService`, adding observability hooks without modifying BLE logic
- `MeshService` — orchestrates `BleCentralService` (scanning/connecting) and `BlePeripheralService` (advertising/receiving)
- `PacketStore` — SQLite-backed deduplication store; packets keyed by UUID, dropped if TTL expired or already seen
- `SentReportCache` — in-memory deduplication for outbound emergency broadcasts (60-second window)

**AI Layer**
- `GemmaService` — wraps `flutter_gemma`; runs Qwen2.5-0.5B-Instruct on-device (CPU); handles download, initialization, per-turn sessions, token limits, and repetition detection
- `ChatService` — per-turn RAG orchestration: normalize → cache check → knowledge retrieval → optional location injection → prompt assembly → LLM stream → cache write
- `KnowledgeRepository` — loads 7 bundled `.txt` knowledge files, splits into passages, computes SHA-256 content hash for cache invalidation
- `Retriever` — deterministic lexical scorer: +2 per keyword match, +1 per query token in passage text; returns top-2 passages
- `PromptBuilder` — assembles prompts within ~140 token budget (system + top-1 passage + optional nearby facilities)
- `ChatCacheStore` — SQLite response cache (`mesh_tester_ai.db`); key = SHA-256(query + knowledge hash + model version)
- `LocationFinder` — Haversine distance search over 2,700+ Singapore facilities from `assets/locations/locations.json`; only injected when user query is location-type (where, nearest, nearby, etc.)

**Voice Layer**
- `VoiceService` — manages STT (`speech_to_text`) and TTS (`flutter_tts`); serializes audio I/O (TTS silenced before STT opens mic); includes iOS AVAudioSession workarounds and prime-listen startup

**Other**
- `LocationService` — wraps `geolocator`; GPS fetched at startup and again when mesh starts
- `LogService` — singleton broadcast log, piped to `LogPage`
- `DummyData` — generates test `EmergencyReport`s and `MeshMessage`s for preload testing
- `DemoData` — static scenario data for demonstration mode

### Knowledge Base

Seven bundled emergency procedure documents in `app/assets/knowledge/`:

| File | Topic |
|------|-------|
| `cpr_instructions.txt` | CPR steps |
| `earthquake_response.txt` | Earthquake safety |
| `fire_evacuation.txt` | Fire evacuation |
| `first_aid_basics.txt` | General first aid |
| `flood_response.txt` | Flood response |
| `general_emergency.txt` | General emergency guidance |
| `hazmat_safety.txt` | Hazmat/chemical safety |

### BLE Mesh Protocol

1. **Preload** — inject packets into local `PacketStore` (hops=0)
2. **Advertise** — `BlePeripheralService` broadcasts RelayGo service UUID
3. **Scan & Connect** — `BleCentralService` finds peers, connects via GATT, writes all locally-stored packets
4. **Receive** — peer's peripheral decodes JSON, increments hops, checks TTL, drops if expired or duplicate
5. **Store & Stream** — valid new packets stored in SQLite, emitted via Dart streams to UI

### Emergency Report Broadcast

Emergency reports are generated from the `HomePage`. The `SentReportCache` prevents the same report from being re-broadcast within 60 seconds. The `GemmaService.shortenDescription()` method uses the on-device LLM to trim descriptions to the 100-character BLE wire budget.

### Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_gemma ^0.12.5` | On-device LLM (Qwen2.5-0.5B) |
| `speech_to_text ^7.0.0` | Speech-to-text |
| `flutter_tts ^4.2.0` | Text-to-speech |
| `flutter_blue_plus ^1.35.3` | BLE central (scanning) |
| `ble_peripheral ^2.4.0` | BLE peripheral (advertising) |
| `geolocator ^13.0.2` | GPS location |
| `sqflite ^2.4.2` | SQLite storage |
| `crypto ^3.0.3` | SHA-256 cache keys |
| `permission_handler ^12.0.1` | Runtime permissions |

### Multi-Device Test Scenarios

**Unidirectional Transfer**
1. Device A: tap "Preload Data", then "Start Mesh"
2. Device B: tap "Start Mesh" only
3. Within 10–30 seconds, Device B receives and stores Device A's packets (hops=1)

**Bidirectional Gossip**
1. Both devices: tap "Preload Data" (fresh UUIDs generated each time), then "Start Mesh"
2. Both devices exchange all packets; each ends up with double the packet count

---

## Backend (`backend/`)

FastAPI server providing REST endpoints and WebSocket push for the dashboard.

### Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### Running

```bash
python main.py
# or
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### API Reference

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/api/reports` | Ingest batch of `EmergencyReport` / `MeshMessage` packets |
| `GET` | `/api/reports` | List most recent reports (default limit 100) |
| `GET` | `/api/reports/geojson` | All reports as GeoJSON `FeatureCollection` |
| `GET` | `/api/directives` | List coordinator directives |
| `POST` | `/api/directives` | Create a new directive |
| `WS` | `/ws` | WebSocket — pushes new reports to connected dashboards in real time |

### Data Models

**EmergencyReport**
```
id, event_id, ts, loc {lat, lng, acc}, type, urg (1-5),
haz[], desc, src, hops, ttl, relay_path[]
```
Types: `fire | medical | structural | flood | hazmat | other`

**MeshMessage**
```
id, ts, src, name, to (optional), body, hops, ttl
```

**Directive**
```
id, ts, src, name, to, zone, body, priority (high|medium|low), hops, ttl
```

### Storage

SQLite via `aiosqlite`. Database initialized at startup via `init_db()`. Reports are deduplicated by `id` on insert. Newly inserted reports are pushed immediately to all connected WebSocket clients.

### Dependencies

```
fastapi==0.115.6
uvicorn[standard]==0.34.0
pydantic==2.10.4
websockets==14.1
aiosqlite==0.20.0
```

---

## Dashboard (`dashboard/`)

React web dashboard for emergency coordinators. Shows a live map of incoming reports and allows issuing directives.

### Setup & Running

```bash
cd dashboard
npm install
npm run dev
```

Open `http://localhost:5173` in a browser. The backend must be running at `http://localhost:8000`.

### Features

- **Map** — MapLibre GL map with markers for each emergency report, color-coded by type and urgency
- **Stats bar** — live counts of incidents by type
- **Incident list** — sortable/filterable list of all received reports
- **Directives panel** — issue and view coordinator directives with priority levels
- **WebSocket** — live report push from backend; no polling required

---

## Data Pipeline (`data_pipeline/`)

Python scripts that fetch Singapore emergency resource locations and build the location index bundled into the mobile app.

### Sources

- **OneMap API** — Singapore government mapping service (hospitals, clinics, fire stations, police stations, shelters)
- **OSM Overpass API** — OpenStreetMap data (AED locations, pharmacies)

### Running

```bash
cd data_pipeline

# Fetch data from all sources
python fetchers/run_all.py

# Build the compact location index
python build_location_index.py
```

### Outputs

| File | Destination | Description |
|------|-------------|-------------|
| `locations.json` | `app/assets/locations/` | Compact location data (name, type, lat, lng, address) |
| `category_relevance.json` | `app/assets/locations/` | Emergency type to relevant facility types mapping |

### Category Relevance Mapping

| Emergency Type | Priority Facility Order |
|---------------|------------------------|
| fire | fire_station, hospital, shelter, aed |
| medical | hospital, aed, clinic, pharmacy |
| structural | shelter, hospital, fire_station |
| flood | shelter, hospital, police_station |
| hazmat | fire_station, hospital, police_station, shelter |

The `LocationFinder` in the mobile app uses these files to surface the nearest relevant facilities for a given emergency type.

---

## Simulator (`simulator/`)

Python mesh network simulator for testing backend ingestion without physical devices.

### Running

The backend must be running first.

```bash
cd simulator
pip install aiohttp
python mesh_sim.py
```

### Behavior

- Spawns 50 virtual mesh nodes distributed across a geographic bounding box
- 5% of nodes are designated online (uplinks to the backend) to simulate realistic sparse internet connectivity
- Nodes communicate within a 0.2 km radius; packets propagate hop-by-hop via gossip
- Emergency events are generated from predefined templates (fire, medical, structural, hazmat)
- Online nodes upload accumulated packets to `POST /api/reports` every tick (0.5s)
- Uploaded packet IDs are tracked to prevent re-uploading

### Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NUM_NODES` | 50 | Total nodes |
| `PERCENT_ONLINE` | 0.05 | Fraction with internet uplink |
| `TICK_INTERVAL` | 0.5s | Simulation tick rate |
| `COMM_RANGE_KM` | 0.2 | BLE communication range |
| `BACKEND_URL` | `http://localhost:8000/api/reports` | Backend endpoint |

---

## iOS Native (`ios-native/`)

A separate SwiftUI iOS frontend that communicates with the Flutter layer via a `MethodChannel` (`com.relaygo/bridge`). The Flutter side exposes all services through `PlatformBridge` in `app/lib/core/platform_bridge.dart`.

This frontend uses `AVAudioRecorder` for voice capture (16kHz, mono, PCM16 WAV), sending audio files to Flutter for transcription.

---

## Permissions Required (Mobile)

| Permission | Platform | Purpose |
|------------|----------|---------|
| `BLUETOOTH_SCAN` | Android | Scan for BLE peers |
| `BLUETOOTH_ADVERTISE` | Android | Advertise as BLE peripheral |
| `BLUETOOTH_CONNECT` | Android | GATT connections |
| `LOCATION` | Android + iOS | Required for BLE scanning on Android; GPS coordinates |
| `BLUETOOTH` | iOS | BLE access |
| `MICROPHONE` | iOS + Android | Voice input (STT) |
| `SPEECH_RECOGNITION` | iOS | On-device speech recognition |
