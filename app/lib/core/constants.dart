/// BLE service and characteristic UUIDs for the RelayGo mesh network.
class BleConstants {
  static const String serviceUuid = '70f2fef4-754d-4560-af60-0cc3d4ddff50';
  static const String packetCharUuid = '300a7b48-d3e2-4114-8f43-8f0a05a41de1';
  static const String messageCharUuid = 'e8c45f49-5f12-4ebf-897b-8919b48624bd';

  static const Duration scanInterval = Duration(seconds: 3);
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const int requestMtu = 247;
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
  static const String directivesEndpoint = '/api/directives/pending';
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
