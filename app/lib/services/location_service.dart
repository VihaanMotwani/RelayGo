import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      // 1. Fast path: check if we have a recent cached location (works instantly offline)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        // If the location is less than 5 minutes old, purely rely on it.
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age.inMinutes < 5) {
          return lastKnown;
        }
      }

      // 2. Slow path: Request a fresh location.
      // In airplane mode, Assisted-GPS (A-GPS) relies on cell towers/WiFi, which are offline.
      // The phone must negotiate directly with satellites ("cold start"), so we increase the timeout.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy
              .medium, // Medium allows relying on slightly less accurate signals, which is faster.
          timeLimit: Duration(
            seconds: 20,
          ), // Increased for raw GPS satellite fix.
        ),
      );
    } catch (e) {
      // 3. Fallback: If getting a fresh position times out (or fails), use the old cached one even if it's stale.
      return await Geolocator.getLastKnownPosition();
    }
  }
}
