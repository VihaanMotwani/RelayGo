# Android Native Setup

## Prerequisites

1. Android Studio (Arctic Fox or later)
2. Flutter SDK installed and in PATH
3. JDK 17

## Setup Steps

### 1. Build Flutter Module

First, build the Flutter module for Android:

```bash
cd ../app
flutter pub get
flutter build aar
```

This generates the Flutter AAR in `../app/build/host/outputs/repo/`.

### 2. Open in Android Studio

1. Open Android Studio
2. Select "Open" and navigate to `android-native/`
3. Wait for Gradle sync to complete

### 3. Configure Flutter Integration

After building the Flutter AAR, uncomment the Flutter dependency in `app/build.gradle.kts`:

```kotlin
// Change this:
// implementation(project(":flutter"))

// To this:
implementation(project(":flutter"))
```

Also ensure `settings.gradle.kts` correctly points to the Flutter module.

### 4. Run on Device

1. Connect an Android device or start an emulator
2. Click Run (green play button) or press Shift+F10

## Project Structure

```
android-native/
├── app/
│   ├── src/main/
│   │   ├── java/com/relaygo/
│   │   │   ├── MainActivity.kt       # Main entry, tab navigation
│   │   │   ├── RelayGoApp.kt         # Application class, Flutter engine
│   │   │   ├── RelayViewModel.kt     # State management
│   │   │   ├── FlutterBridge.kt      # Platform channel to Flutter
│   │   │   └── ui/
│   │   │       ├── screens/
│   │   │       │   ├── SOSScreen.kt      # SOS button with pulse
│   │   │       │   ├── ChatScreen.kt     # AI assistant chat
│   │   │       │   ├── NearbyScreen.kt   # Mesh broadcasts
│   │   │       │   └── SettingsScreen.kt # Relay toggle
│   │   │       └── theme/
│   │   │           └── Theme.kt      # Material3 dark theme
│   │   ├── res/
│   │   │   ├── drawable/             # Navigation icons
│   │   │   ├── mipmap-*/             # App icons
│   │   │   └── values/               # Strings, themes
│   │   └── AndroidManifest.xml
│   └── build.gradle.kts
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

## Architecture

```
┌─────────────────────────────────────┐
│     Android Native UI (Compose)     │
├─────────────────────────────────────┤
│   MethodChannel (com.relaygo/bridge)│
├─────────────────────────────────────┤
│     Flutter Headless Module         │
│  ┌─────────────────────────────────┐│
│  │ AI Service (Cactus LLM/STT/RAG) ││
│  │ Mesh Service (BLE networking)   ││
│  │ Backend Sync                    ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

## Permissions

The app requests:
- **Bluetooth**: For mesh networking (always, with user toggle)
- **Location**: For BLE scanning (when in use)
- **Microphone**: For voice input (when in use)
- **Internet**: For responder data sync
- **Foreground Service**: For background relay mode

## Troubleshooting

### Gradle Sync Failed
- Ensure JDK 17 is selected in Android Studio settings
- Run `./gradlew clean` and sync again

### Flutter Module Not Found
- Run `flutter build aar` in the `../app` directory
- Check that `settings.gradle.kts` path is correct

### App Crashes on Start
- Check logcat for errors
- Ensure Flutter engine is properly initialized
