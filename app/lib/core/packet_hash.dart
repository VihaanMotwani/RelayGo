import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for generating deterministic, content-addressable
/// packet IDs based on SHA-256 hashes of the packet contents.
class PacketHash {
  /// Computes a deterministic ID for an EmergencyReport.
  /// Format: SHA-256("report|{src}|{ts}|{type}|{lat},{lng}|{desc}")
  static String computeReportId(
    String src,
    int ts,
    String type,
    double lat,
    double lng,
    String desc,
  ) {
    final canonical = 'report|$src|$ts|$type|$lat,$lng|$desc';
    return _hashParams(canonical);
  }

  /// Computes a deterministic ID for a MeshMessage.
  /// Format: SHA-256("msg|{src}|{ts}|{to}|{body}")
  static String computeMessageId(String src, int ts, String? to, String body) {
    final target = to ?? 'broadcast';
    final canonical = 'msg|$src|$ts|$target|$body';
    return _hashParams(canonical);
  }

  static String _hashParams(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    // Truncate to first 16 hex characters (64 bits) for BLE payload compactness
    // 64 bits offers virtually zero collision chance for emergency scale
    return digest.toString().substring(0, 16);
  }
}
