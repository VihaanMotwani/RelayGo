# RelayGo iOS Native Setup

This guide explains how to set up the SwiftUI native iOS app that uses Flutter as a backend service layer.

## Architecture

```
ios-native/
├── RelayGo.xcodeproj      # Xcode project
├── RelayGo/               # Swift source files
│   ├── RelayGoApp.swift   # App entry point
│   ├── FlutterBridge.swift # Flutter engine + MethodChannel bridge
│   ├── RelayService.swift  # Main service (uses FlutterBridge)
│   ├── ContentView.swift   # Tab navigation
│   ├── SOSView.swift       # Emergency SOS screen
│   ├── ChatView.swift      # AI assistant chat
│   ├── NearbyView.swift    # Mesh network broadcasts
│   ├── SettingsView.swift  # App settings
│   ├── GeneratedPluginRegistrant.h/m  # Flutter plugin registration
│   └── Info.plist          # Privacy permissions + background modes
├── Assets.xcassets/       # App icons and images
└── Flutter/               # Pre-built Flutter frameworks (gitignored)
    ├── Debug/
    ├── Release/
    └── GeneratedPluginRegistrant.h/m
```

## Prerequisites

- Xcode 15+
- iOS 18.0+ deployment target
- Flutter SDK (for building frameworks)

## Step 1: Build Flutter Frameworks

From the `app/` directory:

```bash
cd app
flutter pub get
flutter build ios-framework --output=../ios-native/Flutter
```

This generates:
- `Flutter/Debug/` - Debug frameworks
- `Flutter/Release/` - Release frameworks
- `Flutter/GeneratedPluginRegistrant.h/m` - Plugin registration

## Step 2: Copy ObjectBox Framework

ObjectBox.xcframework is not included in the flutter build output. Copy it manually:

```bash
cp -R app/ios/Pods/ObjectBox/ObjectBox.xcframework ios-native/Flutter/Release/
cp -R app/ios/Pods/ObjectBox/ObjectBox.xcframework ios-native/Flutter/Debug/
```

## Step 3: Xcode Project Configuration

### 3.1 Open Project

Open `ios-native/RelayGo.xcodeproj` in Xcode.

### 3.2 Add Frameworks

In **General** > **Frameworks, Libraries, and Embedded Content**, add all `.xcframework` files from `Flutter/Release/`:

| Framework | Embed |
|-----------|-------|
| App.xcframework | Embed & Sign |
| Flutter.xcframework | Embed & Sign |
| ObjectBox.xcframework | Embed & Sign |
| ble_peripheral.xcframework | Embed & Sign |
| connectivity_plus.xcframework | Embed & Sign |
| device_info_plus.xcframework | Embed & Sign |
| flutter_blue_plus_darwin.xcframework | Embed & Sign |
| geolocator_apple.xcframework | Embed & Sign |
| objectbox_flutter_libs.xcframework | Embed & Sign |
| package_info_plus.xcframework | Embed & Sign |
| permission_handler_apple.xcframework | Embed & Sign |
| record_ios.xcframework | Embed & Sign |
| shared_preferences_foundation.xcframework | Embed & Sign |
| sqflite_darwin.xcframework | Embed & Sign |
| objective_c.framework | Embed & Sign |

### 3.3 Build Settings

| Setting | Value |
|---------|-------|
| **Objective-C Bridging Header** | `RelayGo/RelayGo-Bridging-Header.h` |
| **Framework Search Paths** | `$(PROJECT_DIR)/Flutter/$(CONFIGURATION)` |
| **Other Linker Flags** | `-ObjC` |
| **iOS Deployment Target** | `18.0` |

### 3.4 Signing & Capabilities

1. Select your **Team** for code signing
2. Add **Background Modes** capability:
   - [x] Uses Bluetooth LE accessories
   - [x] Acts as a Bluetooth LE accessory
   - [x] Location updates
   - [x] Background fetch

### 3.5 Info.plist (Privacy Permissions)

These should already be in `RelayGo/Info.plist`:

| Key | Description |
|-----|-------------|
| NSBluetoothAlwaysUsageDescription | BLE mesh networking |
| NSBluetoothPeripheralUsageDescription | BLE advertising |
| NSLocationWhenInUseUsageDescription | Location tagging |
| NSLocationAlwaysAndWhenInUseUsageDescription | Background relay |
| NSMicrophoneUsageDescription | Voice-to-text |

## Step 4: Build and Run

1. **Clean build**: Cmd + Shift + K
2. **Build**: Cmd + B
3. **Run**: Cmd + R

## First Launch Behavior

On first launch, the app will:

1. Start the Flutter engine
2. Download AI models (~100-500MB):
   - LLM (language model)
   - STT (speech-to-text / Whisper)
   - RAG knowledge base
3. Initialize BLE mesh service

Progress is shown on the loading screen and logged to console with `[RelayGo]` prefix.

## Console Logging

The app logs important events to the Xcode console:

```
[RelayGo] ========== INITIALIZATION STARTED ==========
[RelayGo] Starting Flutter engine...
[RelayGo] Flutter engine running
[RelayGo] Plugins registered
[RelayGo] Method channel ready
[RelayGo] Calling Flutter initialize()...
[RelayGo] Progress: Downloading language model...
[RelayGo] Progress: LLM: 45%
[RelayGo] Progress: Initializing language model...
[RelayGo] Progress: Loading knowledge base...
[RelayGo] Progress: Downloading speech model...
[RelayGo] Progress: STT: 80%
[RelayGo] Progress: Ready
[RelayGo] Flutter initialize() completed
[RelayGo] ========== INITIALIZATION COMPLETE ==========
```

## Troubleshooting

### "Library not loaded: ObjectBox.framework"

Copy ObjectBox.xcframework manually (see Step 2).

### "No such module 'Flutter'"

Ensure Framework Search Paths includes `$(PROJECT_DIR)/Flutter/$(CONFIGURATION)`.

### BLE not working

- BLE requires a **physical device** (not simulator)
- Ensure Bluetooth permission is granted
- Check Background Modes capability is enabled

### App crashes on launch

Check the console for the actual error. Common causes:
- Missing Info.plist privacy keys
- Missing framework not embedded
- Bridging header not configured

## Updating Flutter Code

When you modify Flutter/Dart code:

1. Rebuild frameworks:
   ```bash
   cd app
   flutter build ios-framework --output=../ios-native/Flutter
   ```

2. In Xcode: Clean (Cmd+Shift+K) and rebuild (Cmd+B)

## Communication Flow

```
SwiftUI View
    │
    ▼
RelayService (Swift)
    │
    ▼
FlutterBridge (Swift)
    │
    ▼ MethodChannel("com.relaygo/bridge")
    │
PlatformBridge (Dart)
    │
    ├──▶ AiService (on-device LLM, STT, RAG)
    │
    └──▶ MeshService (BLE central + peripheral)
```
