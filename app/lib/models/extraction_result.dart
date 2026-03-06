import 'dart:convert';

/// Confidence level for an extracted field.
enum FieldConfidence { high, medium, low }

/// Structured result from the LLM emergency extraction (Turn 2).
///
/// Parsed from the model's JSON output. Each field carries a confidence
/// tag so the UI can flag uncertain values for user confirmation.
class ExtractionResult {
  final String
  type; // 'fire', 'medical', 'structural', 'flood', 'hazmat', 'other'
  final int urg; // 1–5
  final List<String> haz; // may be empty
  final String desc; // ≤100 chars ideally

  final FieldConfidence typeConfidence;
  final FieldConfidence urgConfidence;
  final FieldConfidence descConfidence;

  const ExtractionResult({
    required this.type,
    required this.urg,
    this.haz = const [],
    required this.desc,
    this.typeConfidence = FieldConfidence.high,
    this.urgConfidence = FieldConfidence.high,
    this.descConfidence = FieldConfidence.high,
  });

  /// Valid emergency types.
  static const validTypes = {
    'fire',
    'medical',
    'structural',
    'flood',
    'hazmat',
    'other',
  };

  /// Parse from the LLM's JSON output.
  ///
  /// Returns `null` if:
  /// - JSON is malformed
  /// - `type` is null (model determined: not an emergency)
  /// - Required fields are missing
  static ExtractionResult? fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'];
      if (type == null) return null; // Model says: not an emergency

      final typeStr = type.toString().toLowerCase();
      if (!validTypes.contains(typeStr)) return null;

      final urg = json['urg'];
      if (urg == null) return null;
      final urgInt = (urg is int) ? urg : int.tryParse(urg.toString());
      if (urgInt == null || urgInt < 1 || urgInt > 5) return null;

      final desc = json['desc'];
      if (desc == null || desc.toString().trim().isEmpty) return null;

      // Parse hazards
      final hazRaw = json['haz'];
      final haz = <String>[];
      if (hazRaw is List) {
        for (final h in hazRaw) {
          if (h is String && h.trim().isNotEmpty) haz.add(h.trim());
        }
      } else if (hazRaw is String && hazRaw.trim().isNotEmpty) {
        haz.addAll(
          hazRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }

      // Parse confidence
      final conf = json['c'];
      final typeConf = _parseConfidence(conf, 't');
      final urgConf = _parseConfidence(conf, 'u');
      final descConf = _parseConfidence(conf, 'd');

      return ExtractionResult(
        type: typeStr,
        urg: urgInt,
        haz: haz,
        desc: desc.toString().trim(),
        typeConfidence: typeConf,
        urgConfidence: urgConf,
        descConfidence: descConf,
      );
    } catch (_) {
      return null;
    }
  }

  /// Try to parse an [ExtractionResult] from a raw string that may contain
  /// JSON embedded in prose. Extracts the first balanced `{...}` block.
  ///
  /// Uses a balanced-brace scanner instead of greedy indexOf/lastIndexOf
  /// to correctly handle nested objects (like `"c":{"t":"high"}`) and
  /// ignore trailing text or additional JSON blocks.
  static ExtractionResult? tryParse(String raw) {
    try {
      final start = raw.indexOf('{');
      if (start < 0) return null;

      // Walk forward from the first '{', tracking brace depth.
      int depth = 0;
      for (int i = start; i < raw.length; i++) {
        if (raw[i] == '{') depth++;
        if (raw[i] == '}') depth--;
        if (depth == 0) {
          final jsonStr = raw.substring(start, i + 1);
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return fromJson(map);
        }
      }
      return null; // Unbalanced braces
    } catch (_) {
      return null;
    }
  }

  static FieldConfidence _parseConfidence(dynamic conf, String key) {
    if (conf is! Map) return FieldConfidence.medium;
    final val = conf[key]?.toString().toLowerCase();
    return switch (val) {
      'high' => FieldConfidence.high,
      'low' => FieldConfidence.low,
      _ => FieldConfidence.medium,
    };
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'urg': urg,
    'haz': haz,
    'desc': desc,
    'c': {
      't': typeConfidence.name,
      'u': urgConfidence.name,
      'd': descConfidence.name,
    },
  };
}
