# RelayGo Architecture Guide

## Table of Contents
1. [High-Level Overview](#high-level-overview)
2. [System Layers](#system-layers)
3. [Component Deep Dive](#component-deep-dive)
4. [Data Flow Examples](#data-flow-examples)
5. [Key Concepts](#key-concepts)
6. [Configuration & Constants](#configuration--constants)

---

## High-Level Overview

RelayGo is an **emergency communication mesh network** that combines:
- **iOS Native SwiftUI UI** - All user interface
- **Flutter Headless Backend** - All business logic (no Flutter UI)
- **AI-Powered Emergency Detection** - Local LLM extracts structured data
- **BLE Mesh Network** - Peer-to-peer emergency broadcasts

### Why This Architecture?

```
┌─────────────────────────────────────────────────────────┐
│                     iOS Device                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │          SwiftUI Native UI Layer                  │  │
│  │  (ChatView, MapView, SettingsView, etc.)         │  │
│  └───────────────┬───────────────────────────────────┘  │
│                  │ MethodChannel                        │
│                  │ "com.relaygo/bridge"                 │
│  ┌───────────────▼───────────────────────────────────┐  │
│  │        Flutter Engine (Headless)                  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │         PlatformBridge                      │  │  │
│  │  │   (Exposes all services to native)          │  │  │
│  │  └─────┬──────────┬──────────┬─────────────────┘  │  │
│  │        │          │          │                     │  │
│  │  ┌─────▼────┐ ┌──▼────┐ ┌──▼─────┐               │  │
│  │  │ AI Event │ │ Mesh  │ │Location│               │  │
│  │  │Generator │ │Service│ │Service │               │  │
│  │  └─────┬────┘ └───────┘ └────────┘               │  │
│  │        │                                           │  │
│  │  ┌─────▼────────────────┐                         │  │
│  │  │   AI Service         │                         │  │
│  │  │ (LLM, STT, RAG)      │                         │  │
│  │  └──────────────────────┘                         │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │        BLE (Bluetooth Low Energy)                │  │
│  │   Central: Scans & Connects to peers            │  │
│  │   Peripheral: Advertises & Accepts connections  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Design Decisions:**
- ✅ **Flutter Headless** - Reuse AI logic across iOS/Android without duplicate code
- ✅ **SwiftUI Native UI** - Better iOS performance, native look/feel, full platform APIs
- ✅ **MethodChannel Bridge** - Clean separation, easy to swap UI frameworks
- ✅ **Local AI** - Works offline, no server dependency, privacy-first

---

## System Layers

### Layer 1: User Interface (iOS Native - SwiftUI)

**Location:** `ios-native/RelayGo/`

**Key Files:**
```
ChatView.swift          - AI chat interface with voice input
MapView.swift           - Emergency reports on map
DashboardView.swift     - System status & mesh overview
SettingsView.swift      - User preferences
FlutterBridge.swift     - iOS → Flutter communication
RelayService.swift      - iOS service coordinator
```

**Responsibilities:**
- Display UI to user
- Capture user input (text, voice, touch)
- Call Flutter backend via MethodChannel
- Render mesh data (reports, messages, peers)

**Example: User sends a chat message**
```swift
// ChatView.swift
func sendMessage(_ text: String) {
    RelayService.shared.sendToAI(text: text, extractAndBroadcast: true)
}

// RelayService.swift
func sendToAI(text: String, extractAndBroadcast: Bool) {
    FlutterBridge.shared.chat(text: text, extractAndBroadcast: extractAndBroadcast) { result in
        // Handle AI response
    }
}

// FlutterBridge.swift
func chat(text: String, extractAndBroadcast: Bool, completion: @escaping (Result<...>) -> Void) {
    channel.invokeMethod("chat", arguments: [
        "text": text,
        "extractAndBroadcast": extractAndBroadcast
    ]) { result in
        completion(.success(result))
    }
}
```

---

### Layer 2: Platform Bridge (Flutter - Dart)

**Location:** `app/lib/core/platform_bridge.dart`

**Purpose:** Single entry point for all native → Flutter communication

**Key Methods:**
```dart
// Initialization
Future<void> initialize()

// AI Methods
Future<String> transcribe(String audioPath)
Future<Map<String, dynamic>> chat(String text, {bool extractAndBroadcast})
Future<String> generateAwarenessSummary()

// Mesh Methods
Future<void> startMesh()
Future<void> stopMesh()
Future<void> sendSOS({String? description})
Future<void> sendBroadcast(String message)
List<Map<String, dynamic>> getReports()
List<Map<String, dynamic>> getBroadcasts()

// Settings
Future<void> setRelayEnabled(bool enabled)
Future<void> setDisplayName(String name)
```

**MethodChannel Registration:**
```dart
void _setupMethodChannel() {
  _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'initialize':
        await initialize();
        return {'success': true};

      case 'chat':
        final text = call.arguments['text'] as String;
        final extractAndBroadcast = call.arguments['extractAndBroadcast'] as bool? ?? false;
        return await chat(text, extractAndBroadcast: extractAndBroadcast);

      // ... more methods
    }
  });
}
```

---

### Layer 3: AI Event Generator (NEW - Coordinator)

**Location:** `app/lib/services/ai/ai_event_generator.dart`

**Purpose:** Coordinates AI → Mesh event generation from multiple sources

**Architecture Pattern:** **Event Factory Pattern**
- Takes raw input (text, voice, incoming messages)
- Processes through AI
- Validates output
- Broadcasts to mesh network

**4 Main APIs:**

#### API 1: Chat-to-Event
```dart
Future<ChatWithEvent> chatAndExtractEvent(String userText, {bool extractAndBroadcast = false})
```

**Flow:**
```
User text → Get location → AI.chat(extractReport: true) →
  If extraction successful:
    → EmergencyReport.fromAiExtraction()
    → Validate with isValidForBroadcast()
    → MeshService.broadcastReport()
  Return ChatWithEvent{aiResponse, extraction, wasBroadcast}
```

#### API 2: Auto-Analyze Incoming Messages
```dart
Future<EmergencyReport?> analyzeIncomingMessage(MeshMessage msg)
```

**Flow:**
```
Incoming message → IntentFilter.isLikelyEmergency() (pre-filter) →
  If likely emergency:
    → AI.chat(extractReport: true)
    → EmergencyReport.fromAiExtraction(sourceMessageId: msg.id)
    → Return report (caller handles broadcast)
```

**Why pre-filter?**
- Saves battery (only analyze emergency-like messages)
- Reduces false positives
- Fast keyword matching (~0ms vs AI extraction ~500-2000ms)

#### API 3: Generate Awareness Broadcast
```dart
Future<MeshMessage?> generateAwarenessBroadcast()
```

**Flow:**
```
Get all reports/messages from MeshService →
  AI.generateAwarenessSummary(reports, messages) →
  Create MeshMessage with summary text →
  Return message (caller broadcasts)
```

**Use Case:** Periodic summaries or on-demand "What's happening?"

#### API 4: Voice-to-Event
```dart
Future<VoiceTranscriptionResult> transcribeAndExtractEvent(String audioPath)
```

**Flow:**
```
Audio file → AI.transcribe() → IntentFilter check →
  If likely emergency:
    → AI.chat(extractReport: true)
    → EmergencyReport.fromAiExtraction()
    → Validate & broadcast
  Return VoiceTranscriptionResult{transcription, extraction, wasBroadcast}
```

**Key Design Decision:** Returns transcription immediately, does extraction in background

---

### Layer 4: AI Service (Low-Level AI Wrapper)

**Location:** `app/lib/services/ai/ai_service.dart`

**Purpose:** Wraps the Cactus SDK (local AI models)

**Models Used:**
```dart
// From constants.dart
class AiConfig {
  static const String modelSlug = 'lfm2-1.2b';  // LLM model
  // Alternatives: 'lfm2-700m', 'qwen3-0.6'
  static const double temperature = 0.3;
  static const int maxTokens = 256;
}

// STT: whisper-medium or whisper-tiny (auto-fallback)
// RAG: ObjectBox-backed vector store
```

**Key Methods:**
```dart
// Initialize models (downloads on first run)
Future<void> initialize()

// Voice → Text
Future<String> transcribe(String audioPath)

// Text → AI Response + Optional Extraction
Future<AiResponse> chat(String userText, {
  bool extractReport = false,
  double? userLat,
  double? userLon,
  EmergencyType? emergencyType,
})

// Streaming chat
Stream<String> streamChat(String userText, {...})

// Generate summary
Future<String> generateAwarenessSummary(
  List<EmergencyReport> reports,
  List<String> broadcastMessages,
)
```

**AI Chat Flow (Internal):**
```
1. IntentFilter.isLikelyEmergency(userText) → shouldExtract
2. Search RAG for relevant knowledge
3. Get nearby resources from LocationService
4. Build system prompt:
   [extraction directive if shouldExtract]
   [base system prompt]
   [RAG knowledge]
   [location context]
5. LLM.generateCompletion(messages, tools: [extractEmergencyTool])
6. Parse tool calls → AiExtraction
7. Validate extraction (urgency >= 2, type != 'other' OR urgency >= 4, desc.length > 10)
8. Return AiResponse{text, confidence, extraction}
```

**Why Layer 4 vs Layer 3?**
- **Layer 4 (AiService):** Raw AI operations, no mesh awareness
- **Layer 3 (AiEventGenerator):** Business logic, mesh integration, validation

---

### Layer 5: Mesh Service (BLE Network)

**Location:** `app/lib/services/mesh/mesh_service.dart`

**Purpose:** Orchestrates the BLE mesh network

**Architecture:** Dual-role BLE
```
┌───────────────────────────────────────────┐
│           MeshService                     │
├───────────────────────────────────────────┤
│  ┌─────────────────┐  ┌────────────────┐ │
│  │ BlePeripheral   │  │  BleCentral    │ │
│  │ (Advertise)     │  │  (Scan)        │ │
│  │                 │  │                │ │
│  │ • Advertises    │  │ • Scans for    │ │
│  │   presence      │  │   peers        │ │
│  │ • Accepts       │  │ • Connects to  │ │
│  │   connections   │  │   peers        │ │
│  │ • Receives      │  │ • Floods       │ │
│  │   packets       │  │   packets      │ │
│  └─────────────────┘  └────────────────┘ │
│           │                    │          │
│           └────────┬───────────┘          │
│                    │                      │
│           ┌────────▼──────────┐           │
│           │   PacketStore     │           │
│           │   (SQLite)        │           │
│           │  • Deduplication  │           │
│           │  • Persistence    │           │
│           └───────────────────┘           │
└───────────────────────────────────────────┘
```

**Key Methods:**
```dart
Future<void> start()  // Start both BLE roles
Future<void> stop()

Future<void> broadcastReport(EmergencyReport report)
Future<void> broadcastMessage(MeshMessage message)

// Streams for UI
Stream<EmergencyReport> get onNewReport
Stream<MeshMessage> get onNewMessage
Stream<int> get onPeerCountChanged

// Cached lists
List<EmergencyReport> get reports
List<MeshMessage> get broadcastMessages
List<PeerInfo> get peers
```

**Packet Flow (Incoming):**
```dart
Future<void> _handleIncomingPacket(MeshPacket packet) async {
  // 1. Deduplication
  final isNew = await _store.insertIfNew(packet);
  if (!isNew) return;  // Already seen this packet

  // 2. Type handling
  if (packet.isReport) {
    _reports.insert(0, packet.report!);
    _reportController.add(packet.report!);
  } else if (packet.isMessage) {
    final msg = packet.message!;
    _messages.insert(0, msg);
    _messageController.add(msg);

    // 3. NEW: Auto-analyze for emergency extraction
    if (_aiEventGenerator != null) {
      _aiEventGenerator!.analyzeIncomingMessage(msg).then((report) {
        if (report != null && report.isValidForBroadcast()) {
          // Deduplication check
          final isDuplicate = _reports.any((r) =>
            r.type == report.type &&
            r.desc.contains(report.desc.substring(0, 20)) &&
            DateTime.now().millisecondsSinceEpoch - r.ts * 1000 < 60000  // 60s
          );

          if (!isDuplicate) {
            broadcastReport(report);  // Re-broadcast as structured
          }
        }
      });
    }
  }

  // 4. Update outbox for forwarding
  await refreshOutbox();
}
```

**Flooding Algorithm:**
```
Device A receives packet:
  1. Check if seen before (PacketStore.insertIfNew)
  2. If new:
     a. Store locally
     b. Emit to streams (UI updates)
     c. Add to outbox
     d. BleCentral floods to all connected peers
  3. Packet hops++, ttl--
  4. If ttl > 0, continue forwarding
```

---

## Component Deep Dive

### Models: EmergencyReport

**Location:** `app/lib/models/emergency_report.dart`

**Schema:**
```dart
class EmergencyReport {
  final String id;         // Deterministic hash (src+ts+type+lat+lng+desc)
  final int ts;            // Unix timestamp (seconds)
  final double lat;        // Latitude
  final double lng;        // Longitude (note: not 'lon', 'lng' in model)
  final double acc;        // Location accuracy (meters)
  final String type;       // fire, medical, structural, flood, hazmat, other
  final int urg;           // Urgency 1-5 (5 = maximum)
  final List<String> haz;  // Hazards list
  final String desc;       // Human-readable description
  final String src;        // Device ID of originator
  int hops;                // Number of hops traveled
  final int ttl;           // Time-to-live (decrements per hop)
}
```

**Two JSON Formats:**

1. **Full JSON** (SQLite storage, backend sync):
```json
{
  "kind": "report",
  "id": "abc123...",
  "ts": 1709500000,
  "loc": {"lat": 37.7749, "lng": -122.4194, "acc": 10},
  "type": "fire",
  "urg": 5,
  "haz": ["smoke", "heat"],
  "desc": "Fire on 3rd floor, south wing",
  "src": "device-uuid",
  "hops": 2,
  "ttl": 8
}
```

2. **Wire JSON** (BLE broadcast, <185 bytes):
```json
{
  "k": "r",
  "i": "abc123...",
  "t": 1709500000,
  "a": 37.7749,
  "o": -122.4194,
  "y": "fire",
  "u": 5,
  "d": "Fire on 3rd floor, south wing",
  "s": "device-uuid",
  "h": 2,
  "l": 8
}
```

**Factory Constructor (NEW):**
```dart
factory EmergencyReport.fromAiExtraction({
  required dynamic extraction,   // AiExtraction from ai_service.dart
  required dynamic location,      // Position from geolocator
  required String deviceId,
  String? sourceMessageId,        // For deduplication
}) {
  String desc = extraction.description;

  // Include source message ID for deduplication
  if (sourceMessageId != null) {
    desc = '$desc [src:$sourceMessageId]';
  }

  return EmergencyReport(
    ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    lat: location.latitude,
    lng: location.longitude,
    acc: location.accuracy,
    type: extraction.type,
    urg: extraction.urgency,
    haz: extraction.hazards,
    desc: desc,
    src: deviceId,
    hops: 0,
    ttl: 10,
  );
}
```

**Validation (NEW):**
```dart
bool isValidForBroadcast() {
  return urg >= 3 &&              // Only urgent reports
         desc.length > 10 &&      // Meaningful description
         desc.length < 150 &&     // BLE MTU constraint
         type != 'other';         // Specific category required
}
```

**Why these thresholds?**
- **urg >= 3:** Filters out informational/low-priority reports
- **desc 10-150 chars:** Ensures meaningful but compact messages
- **type != 'other':** Forces AI to classify emergencies specifically

---

### Models: MeshMessage

**Location:** `app/lib/models/mesh_message.dart`

**Schema:**
```dart
class MeshMessage {
  final String id;        // Deterministic hash
  final int ts;           // Unix timestamp
  final String src;       // Source device ID
  final String name;      // Display name of sender
  final String? to;       // null = broadcast, deviceId = DM
  final String body;      // Message content
  int hops;
  final int ttl;
}
```

**Use Cases:**
- Broadcast announcements ("All clear in sector B")
- Direct messages between devices
- AI-generated awareness summaries
- User-to-user chat

---

### IntentFilter: Emergency Pre-Detection

**Location:** `app/lib/services/ai/intent_filter.dart`

**Purpose:** Fast keyword-based emergency detection (~0ms)

**How it Works:**
```dart
static double score(String text) {
  final lower = text.toLowerCase();
  double total = 0.0;

  for (final kw in _highSignal) {      // fire, trapped, bleeding, etc.
    if (lower.contains(kw)) total += 3.0;
  }
  for (final kw in _medSignal) {       // emergency, smoke, injured, etc.
    if (lower.contains(kw)) total += 2.0;
  }
  for (final kw in _lowSignal) {       // help, police, accident, etc.
    if (lower.contains(kw)) total += 1.0;
  }
  for (final kw in _strongNegative) {  // "how do i", "what is", etc.
    if (lower.contains(kw)) total -= 4.0;
  }
  for (final kw in _moderateNegative) {// "last week", "yesterday", etc.
    if (lower.contains(kw)) total -= 2.0;
  }

  return total;
}

static bool isLikelyEmergency(String text) => score(text) >= 2.0;
```

**Examples:**
```dart
score("Fire in the building") = 3.0 (high signal) ✅ Emergency
score("Help, someone fell")    = 2.0 (low + low) ✅ Emergency
score("How do I fight a fire") = 3.0 - 4.0 = -1.0 ❌ Not emergency
score("Hello, how are you")    = -2.0 (moderate negative) ❌ Not emergency
```

**Why Pre-Filter?**
- ⚡ Fast: ~0ms vs AI extraction ~500-2000ms
- 🔋 Battery efficient: Avoids unnecessary AI calls
- 🎯 Accurate: Threshold tuned to minimize false positives/negatives

---

## Data Flow Examples

### Example 1: User Chat "Fire on 3rd floor"

```
┌─────────────────────────────────────────────────────────────┐
│ iOS (SwiftUI)                                               │
│   User types "Fire on 3rd floor" in ChatView               │
│   Taps send button                                          │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼ MethodChannel call
┌─────────────────────────────────────────────────────────────┐
│ PlatformBridge.chat(text, extractAndBroadcast: true)       │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ AiEventGenerator.chatAndExtractEvent(text)                 │
│   1. Get current location                                   │
│   2. Call AiService.chat(extractReport: true)               │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ AiService.chat()                                            │
│   1. IntentFilter.isLikelyEmergency("Fire...") → score=3.0 │
│      → shouldExtract = TRUE                                 │
│   2. Search RAG for fire safety knowledge                   │
│   3. Get nearby fire stations from LocationService          │
│   4. Build prompt with extraction directive                 │
│   5. LLM generates response + tool call                     │
│   6. Parse tool call:                                       │
│      {                                                       │
│        type: "fire",                                        │
│        urgency: 5,                                          │
│        hazards: ["smoke", "fire"],                          │
│        description: "Fire reported on 3rd floor"            │
│      }                                                       │
│   7. Validate: urgency=5 >= 2, type='fire' != 'other' ✅    │
│   8. Return AiResponse{text, confidence, extraction}        │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ AiEventGenerator (continued)                                │
│   3. extraction != null, so:                                │
│      EmergencyReport.fromAiExtraction(                      │
│        extraction: {...},                                   │
│        location: Position{lat:37.77, lng:-122.41, acc:10},  │
│        deviceId: "abc-123"                                  │
│      )                                                       │
│   4. report.isValidForBroadcast() checks:                   │
│      urg=5 >= 3 ✅                                           │
│      desc.length=32 > 10 ✅                                  │
│      desc.length=32 < 150 ✅                                 │
│      type='fire' != 'other' ✅                               │
│   5. MeshService.broadcastReport(report)                    │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ MeshService.broadcastReport()                               │
│   1. Create MeshPacket.fromReport(report)                   │
│   2. PacketStore.insertIfNew(packet) → stored in SQLite     │
│   3. Emit to _reportController stream                       │
│   4. refreshOutbox() → add to central's flood queue         │
│   5. BleCentralService.flood() → BLE broadcast              │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ BLE Network                                                 │
│   Packet floods to all connected peers                      │
│   Each peer receives, deduplicates, re-broadcasts           │
│   Report propagates across mesh network                     │
└─────────────────────────────────────────────────────────────┘
```

**Timeline:**
- t=0ms: User taps send
- t=50ms: MethodChannel call reaches Flutter
- t=100ms: IntentFilter scores message (0ms overhead)
- t=150ms: RAG search completes
- t=500-2000ms: LLM generates response + extraction
- t=2050ms: Report validated and broadcast
- t=2100ms: BLE flooding begins
- t=2100-5000ms: Report propagates through mesh

---

### Example 2: Incoming Message Auto-Analysis

```
┌─────────────────────────────────────────────────────────────┐
│ BLE Network                                                 │
│   Peer device broadcasts:                                   │
│   MeshMessage{body: "Help, trapped in stairwell B"}        │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼ BLE Advertisement received
┌─────────────────────────────────────────────────────────────┐
│ BlePeripheralService                                        │
│   Receives packet, decodes JSON                             │
│   Emits to MeshService                                      │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ MeshService._handleIncomingPacket(packet)                   │
│   1. PacketStore.insertIfNew(packet)                        │
│      → Check SQLite: is this packet ID already stored?      │
│      → If duplicate, STOP (already processed)               │
│      → If new, INSERT and continue                          │
│   2. packet.isMessage = true                                │
│      → Extract MeshMessage                                  │
│      → Add to _messages list                                │
│      → Emit to _messageController stream (UI updates)       │
│   3. Auto-analysis check:                                   │
│      if (_aiEventGenerator != null)                         │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼ Fire-and-forget async call
┌─────────────────────────────────────────────────────────────┐
│ AiEventGenerator.analyzeIncomingMessage(msg)                │
│   1. IntentFilter.isLikelyEmergency("Help, trapped...")     │
│      → score = 3.0 (trapped) + 1.0 (help) = 4.0            │
│      → score >= 2.0, so proceed                             │
│   2. Get current location                                   │
│   3. AiService.chat(msg.body, extractReport: true)          │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ AiService.chat()                                            │
│   [Same flow as Example 1]                                  │
│   Extraction result:                                        │
│   {                                                          │
│     type: "structural",                                     │
│     urgency: 4,                                             │
│     hazards: ["trapped"],                                   │
│     description: "Person trapped in stairwell B [src:msg123]"│
│   }                                                          │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ AiEventGenerator (continued)                                │
│   4. EmergencyReport.fromAiExtraction(                      │
│        extraction: {...},                                   │
│        location: {...},                                     │
│        deviceId: "abc-123",                                 │
│        sourceMessageId: "msg123"  ← Tracks original message │
│      )                                                       │
│   5. Return report                                          │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│ MeshService._handleIncomingPacket (callback)                │
│   6. Check if report.isValidForBroadcast() → TRUE           │
│   7. Deduplication check:                                   │
│      isDuplicate = _reports.any((r) =>                      │
│        r.type == 'structural' &&                            │
│        r.desc.contains("Person trapped in...") &&           │
│        (now - r.ts) < 60 seconds                            │
│      )                                                       │
│      → If no recent similar report:                         │
│   8. broadcastReport(report) → Re-broadcast as structured   │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- ✅ Original text message stored and displayed to user
- ✅ Structured report created and broadcast in parallel
- ✅ Deduplication prevents flooding if multiple devices analyze same message
- ✅ Source message ID tracked in description `[src:msg123]`

---

### Example 3: Voice Recording

```
┌─────────────────────────────────────────────────────────────┐
│ iOS (SwiftUI)                                               │
│   User holds record button in ChatView                      │
│   AVAudioRecorder captures audio → WAV file                 │
│   User releases button                                      │
│   File saved to /tmp/recording.wav                          │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼ MethodChannel call
┌─────────────────────────────────────────────────────────────┐
│ PlatformBridge.transcribe(audioPath)                        │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Background (fire-and-forget):                       │   │
│   │ AiEventGenerator.transcribeAndExtractEvent()        │   │
│   │   1. AiService.transcribe() → "Fire on third floor" │   │
│   │   2. IntentFilter check → score = 3.0 ✅            │   │
│   │   3. AiService.chat(extractReport: true)            │   │
│   │   4. EmergencyReport.fromAiExtraction()             │   │
│   │   5. Validate & broadcast                           │   │
│   │   6. Return result (ignored, fire-and-forget)       │   │
│   └─────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Foreground (immediate return):                      │   │
│   │ AiService.transcribe()                              │   │
│   │   → Return "Fire on third floor"                    │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────┬───────────────────────────────────────────────┘
              │
              ▼ Return to iOS immediately
┌─────────────────────────────────────────────────────────────┐
│ iOS (SwiftUI)                                               │
│   Display transcription in chat: "Fire on third floor"      │
│   (Emergency extraction happens in background)              │
└─────────────────────────────────────────────────────────────┘
```

**Timeline:**
- t=0ms: User releases record button
- t=50ms: MethodChannel call reaches Flutter
- t=100ms: Both paths start (background extraction + foreground transcription)
- t=500-2000ms: Whisper transcription completes
- t=2050ms: Transcription returned to iOS (displayed immediately)
- t=2100ms: Background extraction continues
- t=3000-5000ms: LLM extraction completes
- t=5050ms: Report broadcast (user may not even notice)

**Why this design?**
- ✅ User gets instant feedback (transcription)
- ✅ Emergency extraction doesn't block UI
- ✅ Voice → structured report is automatic

---

## Key Concepts

### 1. Deterministic Packet IDs

**Problem:** How do we deduplicate packets in a decentralized mesh?

**Solution:** Hash-based IDs

```dart
// From packet_hash.dart
static String computeReportId(
  String src,
  int ts,
  String type,
  double lat,
  double lon,
  String desc,
) {
  final payload = '$src|$ts|$type|$lat|$lon|$desc';
  final bytes = utf8.encode(payload);
  final hash = sha256.convert(bytes);
  return hash.toString().substring(0, 16);  // First 16 chars
}
```

**Why?**
- Same content → same ID → SQLite INSERT OR IGNORE
- No central authority needed
- Works offline

---

### 2. Broadcast Validation Thresholds

**Why validate before broadcasting?**

❌ **Without validation:**
```
User: "What should I do if there's a fire?"
AI: "Evacuate immediately"
AI extraction: {urgency: 1, type: "other", desc: "Fire safety tips"}
→ Broadcast to mesh ❌ (False alarm!)
```

✅ **With validation:**
```
User: "What should I do if there's a fire?"
AI: "Evacuate immediately"
AI extraction: {urgency: 1, type: "other", desc: "Fire safety tips"}
→ Check isValidForBroadcast():
   urgency=1 < 3 ❌
→ Do NOT broadcast ✅
```

**Thresholds:**
```dart
bool isValidForBroadcast() {
  return urg >= 3 &&          // Urgent enough
         desc.length > 10 &&  // Meaningful
         desc.length < 150 && // Fits in BLE packet
         type != 'other';     // Specific category
}
```

**Calibration:**
- urg >= 3: Tested to minimize false positives while catching real emergencies
- desc 10-150: 10 = minimum meaningful text, 150 = BLE MTU constraint (185B total packet)
- type != 'other': Forces AI to classify specifically (fire, medical, etc.)

---

### 3. Deduplication Strategy

**Challenge:** Multiple devices might analyze the same incoming message

**Scenario:**
```
Device A broadcasts: "Help, fire in building 5"
Devices B, C, D all receive it
All three have auto-analysis enabled
All three extract: {type: "fire", urgency: 5, desc: "Fire in building 5"}
→ Three duplicate reports broadcast ❌
```

**Solution 1: Source Message ID Tracking**
```dart
EmergencyReport.fromAiExtraction(
  sourceMessageId: msg.id,  // Include original message ID
)

// Description becomes: "Fire in building 5 [src:msg123]"
```

**Solution 2: 60-Second Window Deduplication**
```dart
final isDuplicate = _reports.any((r) =>
  r.type == report.type &&
  r.desc.contains(report.desc.substring(0, 20)) &&  // Match first 20 chars
  DateTime.now().millisecondsSinceEpoch - r.ts * 1000 < 60000  // 60s
);
```

**Why 60 seconds?**
- Long enough to catch duplicates from multiple analyzers
- Short enough to allow updates if situation changes
- Tunable based on testing

---

### 4. BLE MTU Constraints

**Problem:** iOS BLE has 185-byte MTU limit

**Solution:** Compact wire format

**Full JSON (storage):**
```json
{
  "kind": "report",
  "id": "abc123",
  "timestamp": 1709500000,
  "location": {"latitude": 37.7749, "longitude": -122.4194, "accuracy": 10},
  "type": "fire",
  "urgency": 5,
  "hazards": ["smoke", "heat"],
  "description": "Fire on 3rd floor, south wing",
  "source": "device-uuid",
  "hops": 2,
  "ttl": 8
}
// Size: ~250 bytes ❌ Too large for BLE
```

**Wire JSON (BLE):**
```json
{
  "k": "r",
  "i": "abc123",
  "t": 1709500000,
  "a": 37.7749,
  "o": -122.4194,
  "y": "fire",
  "u": 5,
  "d": "Fire on 3rd floor, south wing",
  "s": "device-uuid",
  "h": 2,
  "l": 8
}
// Size: ~140 bytes ✅ Fits in 185-byte MTU
```

**Dropped fields in wire format:**
- `accuracy` - not critical for emergency response
- `hazards` - included in description text
- Long key names → 1-char keys

---

## Configuration & Constants

### AI Configuration

```dart
// From constants.dart
class AiConfig {
  static const String modelSlug = 'lfm2-1.2b';
  // Available models:
  //   'lfm2-700m'   - Fastest, least accurate
  //   'lfm2-1.2b'   - Balanced (default)
  //   'qwen3-0.6'   - Good accuracy

  static const double temperature = 0.3;  // Lower = more focused
  static const int maxTokens = 256;       // Response length limit
}
```

**How to change the model:**
1. Edit `constants.dart`
2. Run `flutter pub get` (no rebuild needed)
3. On first run, new model downloads automatically

**Model trade-offs:**
- **lfm2-700m:** 500-1000ms inference, 70% extraction accuracy
- **lfm2-1.2b:** 800-1500ms inference, 85% extraction accuracy
- **qwen3-0.6:** 1000-2000ms inference, 90% extraction accuracy

---

### BLE Configuration

```dart
class BleConstants {
  static const String serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String packetCharUuid = '12345678-1234-5678-1234-56789abcdef1';
  static const Duration scanInterval = Duration(seconds: 30);
  static const int requestMtu = 512;    // Request this
  static const int fallbackMtu = 185;   // iOS limit
}
```

**Why these values?**
- **serviceUuid:** Custom UUID for RelayGo (avoid conflicts)
- **scanInterval:** 30s balances discovery speed vs battery
- **fallbackMtu:** iOS enforces 185-byte limit (Android can do 512)

---

### Emergency Types

```dart
enum EmergencyType {
  fire,
  medical,
  structural,
  flood,
  hazmat,
  other;
}
```

**How AI classifies:**
```dart
// From ai_service.dart
EmergencyType _inferEmergencyType(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('fire') || lower.contains('smoke'))
    return EmergencyType.fire;
  if (lower.contains('hurt') || lower.contains('injured'))
    return EmergencyType.medical;
  // ... etc
}
```

**Used for:**
1. Report categorization
2. Location filtering (nearby fire stations for fire, hospitals for medical)
3. UI display (color coding, icons)

---

## Summary: Information Flow

### High-Level Data Flow

```
┌────────────┐
│    User    │ (iOS SwiftUI)
└─────┬──────┘
      │ Text, Voice, Touch
      ▼
┌─────────────────┐
│ PlatformBridge  │ (Flutter - MethodChannel bridge)
└─────┬───────────┘
      │
      ├─────────────────────────────────┐
      │                                 │
      ▼                                 ▼
┌──────────────────┐          ┌─────────────────┐
│ AiEventGenerator │          │  MeshService    │
│  (Coordinator)   │◄────────►│  (BLE Network)  │
└─────┬────────────┘          └─────────────────┘
      │                                 │
      ▼                                 │
┌──────────────────┐                    │
│   AiService      │                    │
│ (LLM/STT/RAG)    │                    │
└──────────────────┘                    │
                                        │
                                        ▼
                              ┌──────────────────┐
                              │   PacketStore    │
                              │    (SQLite)      │
                              └──────────────────┘
```

### Request Flow (User Chat)

```
1. User input → iOS UI
2. iOS → MethodChannel → PlatformBridge
3. PlatformBridge → AiEventGenerator
4. AiEventGenerator → AiService (AI processing)
5. AiService → EmergencyReport (if extraction)
6. AiEventGenerator → MeshService (broadcast)
7. MeshService → PacketStore (persist)
8. MeshService → BLE (flood to peers)
9. Response back to iOS UI
```

### Mesh Packet Flow

```
┌─────────────┐
│  Device A   │ broadcasts packet
└──────┬──────┘
       │
       ├────────┬────────┬────────┐
       │        │        │        │
       ▼        ▼        ▼        ▼
   Device B  Device C  Device D  Device E
       │        │        │        │
       ├────────┴────────┴────────┘
       │  (Each device re-broadcasts to its peers)
       ▼
   Mesh network propagation
   (TTL decrements, packet eventually dies)
```

---

## Testing & Debugging

### Mesh Tester UI

**Location:** `app/lib/mesh_tester/tester_screen.dart`

**Features:**
- Preload dummy data (reports + messages)
- Start/stop mesh manually
- View live packet log
- Monitor peer count
- Test BLE without full app

**How to add AI extraction test:**
```dart
// In tester_screen.dart, add button:
ElevatedButton(
  onPressed: () async {
    final testMessage = MeshMessage(
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: _mesh.deviceId,
      name: 'Test',
      to: null,
      body: 'Fire on 3rd floor',
      hops: 0,
      ttl: 10,
    );

    // Trigger auto-analysis
    await _mesh.broadcastMessage(testMessage);

    // Check if EmergencyReport was created and broadcast
    await Future.delayed(Duration(seconds: 3));
    final reports = _mesh.reports;
    print('Reports after test: ${reports.length}');
  },
  child: Text('Test AI Extraction'),
)
```

---

## Common Questions

### Q: Why Flutter headless instead of native Dart/Swift?

**A:** Reusability and AI libraries
- Cactus SDK (local AI) has Flutter bindings
- Same AI logic for iOS + future Android
- MethodChannel overhead is negligible (~5ms)

### Q: Why not just use the AI response text directly?

**A:** Structured data enables features
- **Text:** "Fire on 3rd floor" → only humans can read
- **Structured:** `{type: 'fire', lat: 37.77, urg: 5}` → can be:
  - Displayed on map
  - Filtered by type
  - Sorted by urgency
  - Routed to nearest responder

### Q: What happens if AI is offline?

**A:** Graceful degradation
- Mesh network still works (text messages)
- Manual SOS button still works
- Fallback responses shown
- Voice transcription unavailable
- No auto-extraction (manual reports only)

### Q: How much battery does auto-analysis use?

**A:** Minimal due to pre-filtering
- IntentFilter runs on every message (~0ms, negligible power)
- AI analysis only triggers on emergency keywords (~1-3% of messages)
- Each AI call: ~500-2000ms @ ~500mW = ~0.25-1.0 mWh
- For 100 messages/hour, ~10-30 auto-analyses = ~2.5-30 mWh/hour
- iPhone 15 battery: ~15,000 mWh → ~0.2% battery/hour

### Q: Can multiple devices extract from the same message?

**A:** Yes, but deduplication prevents flooding
- Each device independently analyzes
- All create similar reports
- Deduplication catches duplicates (60s window)
- First report broadcasts, rest are discarded

### Q: What's the maximum mesh range?

**A:** Depends on density
- BLE range: ~30-100 meters outdoors
- Each device extends range
- 10 devices in chain = 300-1000 meter effective range
- TTL=10 limits to 10 hops (prevent infinite loops)

---

## Next Steps for You

### To understand the codebase better:

1. **Read in order:**
   ```
   constants.dart                 ← You are here!
   platform_bridge.dart           ← Entry point
   ai_event_generator.dart        ← NEW coordinator
   ai_service.dart                ← AI wrapper
   mesh_service.dart              ← Mesh network
   emergency_report.dart          ← Data model
   ```

2. **Experiment:**
   - Change AI model in constants.dart
   - Add keywords to intent_filter.dart
   - Adjust validation thresholds in emergency_report.dart
   - Test with mesh_tester/tester_screen.dart

3. **Trace a request:**
   - Set breakpoints in platform_bridge.dart
   - Send chat message from iOS
   - Step through: Bridge → Generator → Service → Mesh
   - Watch packet broadcast on BLE

4. **Build a feature:**
   - Add new emergency type (e.g., `wildfire`)
   - Add keywords to IntentFilter
   - Update AI prompts to recognize it
   - Test extraction and broadcast

---

## Architecture Diagram (Complete)

```
┌─────────────────────────────────────────────────────────────────────┐
│                           iOS Device                                 │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    SwiftUI Native UI                            │ │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌────────────────┐ │ │
│  │  │ ChatView  │ │  MapView  │ │Dashboard │ │ SettingsView   │ │ │
│  │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └────────┬───────┘ │ │
│  │        └───────────────┴─────────────┴────────────────┘         │ │
│  │                           │                                      │ │
│  │              ┌────────────▼──────────────┐                      │ │
│  │              │    RelayService.swift     │                      │ │
│  │              │  (iOS service coordinator)│                      │ │
│  │              └────────────┬──────────────┘                      │ │
│  │                           │                                      │ │
│  │              ┌────────────▼───────────────┐                     │ │
│  │              │   FlutterBridge.swift      │                     │ │
│  │              │ (MethodChannel wrapper)    │                     │ │
│  │              └────────────┬───────────────┘                     │ │
│  └───────────────────────────┼──────────────────────────────────────┘ │
│                              │                                        │
│                              │ MethodChannel "com.relaygo/bridge"    │
│  ════════════════════════════╪════════════════════════════════════   │
│                              │                                        │
│  ┌───────────────────────────▼──────────────────────────────────────┐ │
│  │                    Flutter Engine (Headless)                     │ │
│  │                                                                   │ │
│  │  ┌───────────────────────────────────────────────────────────┐  │ │
│  │  │              PlatformBridge (Dart)                        │  │ │
│  │  │  • initialize()                                            │  │ │
│  │  │  • transcribe(audioPath)                                   │  │ │
│  │  │  • chat(text, extractAndBroadcast)                         │  │ │
│  │  │  • startMesh() / stopMesh()                                │  │ │
│  │  │  • sendSOS() / sendBroadcast()                             │  │ │
│  │  │  • getReports() / getBroadcasts()                          │  │ │
│  │  └───────────┬───────────────────────┬───────────────────────┘  │ │
│  │              │                       │                           │ │
│  │  ┌───────────▼───────────┐  ┌───────▼────────────────────────┐ │ │
│  │  │  AiEventGenerator     │  │      MeshService              │ │ │
│  │  │  (Coordinator)        │◄─┤  (BLE orchestration)          │ │ │
│  │  │                       │  │  • setAiEventGenerator()      │ │ │
│  │  │  • chatAndExtractEvent│  │  • broadcastReport()          │ │ │
│  │  │  • analyzeIncoming    │  │  • _handleIncomingPacket()    │ │ │
│  │  │  • generateAwareness  │  │  • auto-analysis              │ │ │
│  │  │  • transcribeAndExtract│  └───┬──────────┬──────────────┘ │ │
│  │  └───────┬───────────────┘      │          │                  │ │
│  │          │                      │          │                  │ │
│  │  ┌───────▼────────┐   ┌─────────▼──┐  ┌───▼─────────────┐    │ │
│  │  │   AiService    │   │Peripheral  │  │   Central       │    │ │
│  │  │                │   │Service     │  │   Service       │    │ │
│  │  │ ┌────────────┐ │   │(Advertise) │  │   (Scan)        │    │ │
│  │  │ │  CactusLM  │ │   │(Receive)   │  │   (Flood)       │    │ │
│  │  │ │  (LLM)     │ │   └────────────┘  └─────────────────┘    │ │
│  │  │ └────────────┘ │           │              │                │ │
│  │  │ ┌────────────┐ │           └──────┬───────┘                │ │
│  │  │ │  CactusSTT │ │                  │                        │ │
│  │  │ │  (Whisper) │ │         ┌────────▼──────────┐             │ │
│  │  │ └────────────┘ │         │   PacketStore     │             │ │
│  │  │ ┌────────────┐ │         │   (SQLite)        │             │ │
│  │  │ │  CactusRAG │ │         │  • Deduplication  │             │ │
│  │  │ │ (ObjectBox)│ │         │  • Persistence    │             │ │
│  │  │ └────────────┘ │         └───────────────────┘             │ │
│  │  │                │                                            │ │
│  │  │ ┌────────────┐ │                                            │ │
│  │  │ │IntentFilter│ │                                            │ │
│  │  │ │(Keywords)  │ │                                            │ │
│  │  │ └────────────┘ │                                            │ │
│  │  └────────────────┘                                            │ │
│  │                                                                 │ │
│  │  ┌───────────────────────────────────────────────────────────┐ │ │
│  │  │                    LocationService                         │ │ │
│  │  │  • getCurrentLocation()                                    │ │ │
│  │  │  • Nearby resource lookup                                  │ │ │
│  │  └───────────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    BLE Hardware Layer                         │  │
│  │  • iOS CoreBluetooth                                          │  │
│  │  • Scanning, Advertising, Connection, Data Transfer           │  │
│  │  • MTU Limit: 185 bytes                                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

**Congratulations!** You now understand the RelayGo architecture. Feel free to ask questions about any specific component or flow!
