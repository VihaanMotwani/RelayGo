/// Pure utility class for validating GPS position fixes before
/// accepting them as location updates in the mesh network.
///
/// No Flutter dependencies — fully unit-testable.
class LocationValidator {
  LocationValidator._();

  /// Max speed in m/s used for teleportation detection (120 km/h = 33.3 m/s).
  static const double _maxSpeedMs = 33.3;

  /// Accuracy floor: below this threshold (metres) both fixes are
  /// considered "good enough" regardless of relative change.
  static const double _accuracyFloorMetres = 50.0;

  /// Returns true if the new GPS fix should replace the last known position
  /// based on accuracy quality.
  ///
  /// Rejects a new fix if it is more than 2x worse in accuracy than the
  /// last known good fix (unless both are under the 50m floor, in which
  /// case both are considered acceptable).
  static bool isAcceptableAccuracy({
    required double newAcc,
    required double? lastAcc,
  }) {
    // No reference point — always accept the first fix.
    if (lastAcc == null) return true;

    // Both fixes are within the "good enough" floor: accept.
    if (newAcc <= _accuracyFloorMetres && lastAcc <= _accuracyFloorMetres) {
      return true;
    }

    // Reject if the new fix is more than 2x worse than the last.
    return newAcc <= lastAcc * 2;
  }

  /// Returns true if the reported movement is physically plausible
  /// given the elapsed time since the last fix.
  ///
  /// Uses a maximum speed of 120 km/h. A nil elapsed time (first ever
  /// fix) is always accepted.
  static bool isPhysicallyPlausible({
    required double distanceMetres,
    required int elapsedSeconds,
  }) {
    // First fix — no prior timestamp to compare against.
    if (elapsedSeconds == 0) return true;

    final impliedSpeedMs = distanceMetres / elapsedSeconds;
    return impliedSpeedMs <= _maxSpeedMs;
  }

  /// Returns true if the device has moved far enough to warrant a new
  /// location update being broadcast on the mesh.
  static bool hasMoved({
    required double distanceMetres,
    double thresholdMetres = 25.0,
  }) {
    return distanceMetres > thresholdMetres;
  }
}
