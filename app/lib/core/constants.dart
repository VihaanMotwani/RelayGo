/// BLE service and characteristic UUIDs for the RelayGo mesh network.
class BleConstants {
  static const String serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String packetCharUuid = '12345678-1234-5678-1234-56789abcdef1';
  static const Duration scanInterval = Duration(seconds: 30);
  static const int requestMtu = 512; // Request this from the remote device
  static const int fallbackMtu = 185; // iOS BLE MTU limit / fallback
}

/// Emergency type enum matching the packet format.
enum EmergencyType {
  fire,
  medical,
  structural,
  flood,
  hazmat,
  other;

  String get label {
    switch (this) {
      case EmergencyType.fire:
        return 'Fire';
      case EmergencyType.medical:
        return 'Medical';
      case EmergencyType.structural:
        return 'Structural';
      case EmergencyType.flood:
        return 'Flood';
      case EmergencyType.hazmat:
        return 'Hazmat';
      case EmergencyType.other:
        return 'Other';
    }
  }

  static EmergencyType fromString(String s) {
    return EmergencyType.values.firstWhere(
      (e) => e.name == s.toLowerCase(),
      orElse: () => EmergencyType.other,
    );
  }
}

/// Backend configuration.
class BackendConfig {
  static const String baseUrl =
      'https://localhost:8000'; // CHANGE TO ACTUAL NGROK URL WHEN RUNNING
  static const String reportsEndpoint = '/api/reports';
  static const Duration syncInterval = Duration(seconds: 15);
}

/// AI model configuration.
class AiConfig {
  static const String modelSlug = 'lfm2-1.2b';
  // lfm2-700m, qwen3-0.6
  static const double temperature = 0.3;
  static const int maxTokens = 256;
}

/// Packet defaults.
class PacketDefaults {
  static const int defaultTtl = 10;
}
