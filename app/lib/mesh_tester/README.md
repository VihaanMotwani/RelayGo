# RelayGo BLE Mesh Tester

This directory contains a standalone, minimal Flutter app used to validate the core BLE mesh networking protocols of RelayGo on real hardware, isolated from the main app's UI, AI, and backend sync logic.

## Architecture

The Mesh Tester is built as a wrapper around the physical production mesh services, adding full observability without modifying the underlying code.

- **`MeshTesterApp` & `main_tester.dart`**: Alternate Flutter entry point. Boots a minimal `MaterialApp` without standard providers.
- **`TesterScreen`**: The UI testbench. Displays a dashboard with live peer counts, a summary of stored/received packets, and a live scrolling log panel.
- **`InstrumentedMeshService`**: The core driver. It wraps the production `MeshService` (which in turn uses `BleCentralService`, `BlePeripheralService`, and `PacketStore`). It hooks into the streams (`onNewReport`, `onNewMessage`, `onPeerCountChanged`) to pipe events to the log and tracking counters, while leaving the actual BLE logic untouched.
- **`LogService`**: A singleton that acts as the testbench's standard output. It collects events tagged by their source (`[BLE-CENTRAL]`, `[BLE-PERIPH]`, `[STORE]`, etc.) and broadcasts them to the UI.
- **`DummyData`**: A packet factory that generates a fixed set of 5 `EmergencyReport`s and 3 `MeshMessage`s (2 broadcasts, 1 DM) with varied locations, emergencies, and UUIDs for test injection.

## Data Flow

1. **Preloading**: Tapping "Preload Data" injects `DummyData` directly into the SQLite `PacketStore`, marking them as originating locally (hops = 0).
2. **Advertising**: The `BlePeripheralService` advertises the RelayGo service UUID.
3. **Scanning & Connecting**: The `BleCentralService` scans for peers. When it finds a new peer, it connects, queries the GATT service, and writes all packets currently in its `PacketStore` to the peer's writable characteristic.
4. **Receiving**: The peer's `BlePeripheralService` receives the bytes, decodes the JSON, increments the `hops` counter, checks the `ttl`, and drops the packet if it's expired.
5. **Storing**: Valid packets are pushed to the `MeshService`, which attempts to insert them into the `PacketStore`. The store deduplicates by UUID. If the packet is new, it is saved and broadcasted via Dart streams to the UI.

---

## Instructions to Run

> **Note:** BLE testing *cannot* be performed on simulators or emulators. You must use two or more physical Android/iOS devices.

### 1. Find Your Devices
Connect both testing devices to your computer via USB (with debugging enabled) and find their IDs:
```bash
flutter devices
```

### 2. Install the Tester App
Deploy the tester app to both devices. Do this from the root of the `app/` directory:
```bash
flutter run -d <DEVICE_A_ID> -t lib/mesh_tester/main_tester.dart
flutter run -d <DEVICE_B_ID> -t lib/mesh_tester/main_tester.dart
```

### 3. Execution Scenario: Unidirectional Transfer
1. **On Device A (Sender):**
   - Tap **"Preload Data"**. The log will show 8 packets successfully cached to the SQLite store.
   - Tap **"Start Mesh"**. (Grant Location/Nearby Devices permissions if prompted). The device will start advertising its presence and scanning.
2. **On Device B (Receiver):**
   - Do *not* tap "Preload Data". Let the store remain empty.
   - Tap **"Start Mesh"**.
3. **Verification:**
   - Within 10–30 seconds, Device A will log `[BLE-CENTRAL] Found peer...` and Device B will log `[BLE-PERIPH] Received report...`.
   - Device B's summary card should update to show 5 reports and 3 messages received and stored. Check the log to verify that the `hops` counter has correctly incremented to `1`.

### 4. Execution Scenario: Bidirectional Gossip
Follow the same steps as above, but tap **"Preload Data"** on *both* devices before starting the mesh. Because `DummyData` generates fresh UUIDs on every call, both devices will have 8 unique local packets. When they connect, they will exchange their data, and both devices should end up with a total of 16 stored packets.
