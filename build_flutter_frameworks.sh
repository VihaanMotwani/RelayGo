#!/bin/bash
set -e
cd "$(dirname "$0")/app"

echo "→ flutter clean"
flutter clean

echo "→ flutter pub get"
flutter pub get

# Build both Debug and Release. The iOS simulator Flutter engine is always
# JIT-based and needs kernel_blob.bin, which lives in the Debug xcframework.
echo "→ flutter build ios-framework (Debug + Release)"
flutter build ios-framework --no-profile --output=../ios-native/Flutter

echo "→ patching Release simulator slice with kernel_blob.bin from Debug"
cp ../ios-native/Flutter/Debug/App.xcframework/ios-arm64_x86_64-simulator/App.framework/flutter_assets/kernel_blob.bin \
   ../ios-native/Flutter/Release/App.xcframework/ios-arm64_x86_64-simulator/App.framework/flutter_assets/

echo "→ flutter build ios release (device)"
flutter build ios --release --no-codesign

echo "→ copying ObjectBox, cactus, cactus_util"
cp -R ios/Pods/ObjectBox/ObjectBox.xcframework ../ios-native/Flutter/Release/
cp -R ~/.pub-cache/hosted/pub.dev/cactus-1.3.0/ios/cactus.xcframework ../ios-native/Flutter/Release/
cp -R ~/.pub-cache/hosted/pub.dev/cactus-1.3.0/ios/cactus_util.xcframework ../ios-native/Flutter/Release/

# Compile objective_c.framework for iOS Simulator from source.
# flutter build ios-framework only produces a device (IOS) slice for native
# assets; we compile the simulator slice ourselves using clang (~3 seconds).
echo "→ compiling objective_c.framework for iphonesimulator"
SRC=~/.pub-cache/hosted/pub.dev/objective_c-9.3.0/src
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
SIM_WORK=/tmp/objective_c_sim_fw
rm -rf "$SIM_WORK"
mkdir -p "$SIM_WORK/objective_c.framework"

clang -arch arm64 -arch x86_64 \
  -isysroot "$SIM_SDK" \
  -mios-simulator-version-min=13.0 \
  -dynamiclib \
  -install_name "@rpath/objective_c.framework/objective_c" \
  -framework Foundation \
  -fobjc-arc \
  -I"$SRC" -I"$SRC/include" \
  "$SRC/include/dart_api_dl.c" \
  "$SRC/objective_c.c" \
  "$SRC/objective_c.m" \
  "$SRC/ns_number.m" \
  "$SRC/objective_c_bindings_generated.m" \
  "$SRC/input_stream_adapter.m" \
  "$SRC/observer.m" \
  "$SRC/protocol.m" \
  -o "$SIM_WORK/objective_c.framework/objective_c"

cp "build/native_assets/ios/objective_c.framework/Info.plist" \
   "$SIM_WORK/objective_c.framework/Info.plist"

echo "→ creating objective_c.xcframework (device + simulator)"
rm -rf ../ios-native/Flutter/Release/objective_c.framework
rm -rf ../ios-native/Flutter/Release/objective_c.xcframework
xcodebuild -create-xcframework \
  -framework build/ios/iphoneos/Runner.app/Frameworks/objective_c.framework \
  -framework "$SIM_WORK/objective_c.framework" \
  -output ../ios-native/Flutter/Release/objective_c.xcframework

echo "Done"
ls ../ios-native/Flutter/Release/ | grep objective
