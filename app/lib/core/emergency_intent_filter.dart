/// Pure Dart emergency intent detector — no LLM, fast.
///
/// Biased toward false positives: missing a real emergency is worse
/// than an unnecessary extraction call.
class EmergencyIntentFilter {
  /// Emergency-type keywords (things that ARE emergencies).
  static const _typeKeywords = <String>{
    'fire',
    'flood',
    'flooding',
    'injury',
    'injured',
    'collapse',
    'collapsed',
    'explosion',
    'crash',
    'gas leak',
    'bleeding',
    'unconscious',
    'trapped',
    'earthquake',
    'hazmat',
    'chemical',
    'burning',
    'smoke',
    'drowning',
    'electrocution',
    'avalanche',
    'landslide',
    'tornado',
    'hurricane',
    'gunshot',
    'stabbing',
    'heart attack',
    'stroke',
    'choking',
    'seizure',
    'broken bone',
    'fracture',
  };

  /// Urgency intensifiers (words that signal something serious is happening).
  static const _urgencyKeywords = <String>{
    'help',
    'urgent',
    'emergency',
    'sos',
    'dying',
    'danger',
    'dangerous',
    'severe',
    'critical',
    'rescue',
    'evacuate',
    'evacuation',
    'mayday',
    'ambulance',
    'paramedic',
    'firefighter',
  };

  /// Returns `true` if [text] likely describes an emergency.
  ///
  /// Uses word-boundary matching to avoid false positives like
  /// "fired" triggering "fire". Multi-word keywords (e.g. "gas leak")
  /// are checked as substring matches.
  static bool isEmergency(String text) {
    final lower = text.toLowerCase();

    for (final keyword in _typeKeywords) {
      if (_matchesKeyword(lower, keyword)) return true;
    }
    for (final keyword in _urgencyKeywords) {
      if (_matchesKeyword(lower, keyword)) return true;
    }

    return false;
  }

  /// Matches [keyword] against [text] with word-boundary awareness.
  ///
  /// Multi-word keywords (containing spaces) are matched as substrings.
  /// Single-word keywords use a regex word boundary to prevent partial
  /// matches like "fired" → "fire".
  static bool _matchesKeyword(String text, String keyword) {
    if (keyword.contains(' ')) {
      // Multi-word: substring match is sufficient
      return text.contains(keyword);
    }
    // Single word: use word boundary regex
    final pattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
    return pattern.hasMatch(text);
  }
}
