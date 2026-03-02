class PeerInfo {
  final String deviceId;
  final String displayName;
  DateTime lastSeen;
  int rssi;

  PeerInfo({
    required this.deviceId,
    required this.displayName,
    DateTime? lastSeen,
    this.rssi = 0,
  }) : lastSeen = lastSeen ?? DateTime.now();

  bool get isRecent =>
      DateTime.now().difference(lastSeen).inMinutes < 5;
}
