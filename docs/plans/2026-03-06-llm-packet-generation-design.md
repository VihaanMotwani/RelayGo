# LLM-Driven Emergency Packet Generation

**Date:** 2026-03-06  
**Status:** Approved  
**Scope:** EmergencyReport packets only (MeshMessage path unchanged for v1)

---

## Problem

The mesh tester currently injects fixed dummy packets from `DummyData`. The goal is to replace this with real user-driven `EmergencyReport` packets extracted from the AI chat conversation, validated by the user, then broadcast on the BLE mesh.

---

## Wire Budget

BLE MTU is 185B, iOS uses ~2B control bytes → **183B usable**.

Current `toWireJson` fixed overhead (IDs, timestamps, type, urg, hops, TTL, src): ~80B  
**Available for `desc`:** ~100 chars (enforced at packet build time, truncated with `…` if exceeded)

TTL stays hardcoded at `10` — not user-configurable, not LLM-determined.

---

## Architecture

```
User types message
       │
       ▼
┌─────────────────────┐
│  EmergencyIntentFilter │  ← pure Dart, no LLM, fast
│  keyword/heuristic  │
└────────┬────────────┘
         │ isEmergency?
    YES  │              NO
    ▼                    ▼
┌────────────────┐   ┌───────────────────┐
│  Turn 1        │   │  Turn 1 only      │
│  GemmaService  │   │  guidance stream  │
│  streamChat()  │   │  (no extraction)  │
│  → guidance    │   └───────────────────┘
└────────┬───────┘
         ▼
┌─────────────────────────┐
│  Turn 2 (silent)        │
│  GemmaService           │
│  extractEmergency()     │
│  → strict JSON output   │
└────────┬────────────────┘
         ▼
┌──────────────────┐
│  JSON Parser     │  ← regex, returns ExtractionResult?
│  Confidence tags │     null = no card shown
└────────┬─────────┘
         ▼
┌────────────────────┐
│  PacketBuilder     │
│  + GPS position    │  ← lat/lng/acc from LocationService
│  + TTL=10, src=id  │
│  → EmergencyReport │
└────────┬───────────┘
         ▼
┌──────────────────────────────┐
│  ReportConfirmationSheet     │  ← modal bottom sheet
│  field chips (tap to confirm) │
│  Send disabled until all     │
│  uncertain fields confirmed  │
└────────┬─────────────────────┘
         ▼ user confirms
┌───────────────────────────┐
│  InstrumentedMeshService  │
│  .injectReport(report)    │
└───────────────────────────┘
```

---

## Components

### 1. `EmergencyIntentFilter` (new — `lib/core/emergency_intent_filter.dart`)

Pure Dart utility, no LLM.

**Trigger vocabulary:**
- Emergency types: fire, flood, injury, injured, collapse, explosion, crash, gas leak, bleeding, unconscious, trapped, earthquake, hazmat, chemical
- Urgency intensifiers: help, urgent, emergency, SOS, dying, danger, severe, critical

Returns `bool isEmergency(String text)` — biased toward false positives (missing a real emergency is worse than an extra extraction call).

---

### 2. `GemmaService` additions

#### `streamChat()` — unchanged in signature, gains intent check internally

After Turn 1 completes, checks `EmergencyIntentFilter`. If positive, fires Turn 2 and emits extraction result via a separate stream/callback.

#### `Future<ExtractionResult?> extractEmergency(String userText, String aiResponse)`

Silent second inference call. Prompt instructs model to output **JSON only**, no prose:

```
Extract emergency data from this conversation as JSON only. No other text.

Schema (desc max 100 chars):
{"type":"...","urg":N,"haz":[],"desc":"...","c":{"t":"high|medium|low","u":"high|medium|low","d":"high|medium|low"}}

Types: fire, medical, structural, flood, hazmat, other
Urgency: 1-5 (5=life threatening)
Hazards: gas_leak,fire_spread,structural_collapse,flooding,chemical_spill,downed_power_lines,trapped_people
If not an emergency: {"type":null}

User said: [userText]
AI responded: [aiResponse]
JSON:
```

Parser: regex for `{...}`, `jsonDecode`, maps into `ExtractionResult`. Returns `null` on any parse failure.

---

### 3. `ExtractionResult` (new model — `lib/models/extraction_result.dart`)

```dart
enum FieldConfidence { high, medium, low }

class ExtractionResult {
  final String type;           // 'fire', 'medical', etc.
  final int urg;               // 1–5
  final List<String> haz;      // may be empty
  final String desc;           // ≤100 chars
  final FieldConfidence typeConfidence;
  final FieldConfidence urgConfidence;
  final FieldConfidence descConfidence;
}
```

Fields with `confidence < high` are flagged in the UI. A field is "confirmed" when the user taps it (or if `confidence == high`, auto-confirmed).

---

### 4. `PacketBuilder` (new — `lib/core/packet_builder.dart`)

```dart
EmergencyReport build(ExtractionResult extraction, Position gps)
```

- Truncates `desc` to 100 chars with `…` if needed
- Sets `lat/lng/acc` from `gps`  
- Sets `src` from device ID  
- Sets `ttl = 10`, `hops = 0`  
- Calls `EmergencyReport(...)` — ids auto-computed by constructor

---

### 5. `ReportConfirmationSheet` (new widget — `lib/mesh_tester/report_confirmation_sheet.dart`)

Modal bottom sheet with:
- **Header:** "Send Emergency Report?" with urgency colour strip
- **Field chips:** type, urgency, hazards, description — each tappable
  - `high` confidence: green chip, pre-confirmed  
  - `medium/low` confidence: amber chip with `⚠` icon, requires tap
- **Description field:** inline editable text if user wants to correct it
- **GPS row:** shows current lat/lng (read-only, from LocationService)
- **Send button:** disabled until all amber chips are tapped/confirmed
- **Dismiss:** cancels — no packet sent

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| JSON parse fails | No bottom sheet; chat continues normally |
| `type == null` from model | No bottom sheet (model determined not an emergency) |
| GPS unavailable | Sheet shows "Location unavailable" — Send still allowed (report sent with `acc=999` as sentinel) |
| User dismisses sheet | Nothing sent; conversation continues |
| Desc > 100 chars after edit | Character counter shown, Send disabled until ≤100 |

---

## Testing Plan

- Unit: `EmergencyIntentFilter` with positive/negative/edge cases
- Unit: JSON parser with valid, malformed, and null-type responses
- Unit: `PacketBuilder` desc truncation, GPS injection, field correctness
- Widget: `ReportConfirmationSheet` — confirm/dismiss flow, Send enable/disable logic
- Integration: full flow from typed message → packet injected into `InstrumentedMeshService`
