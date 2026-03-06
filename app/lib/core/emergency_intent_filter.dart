/// Weighted keyword-based emergency intent detector — no LLM, fast.
///
/// Uses a scored approach with positive and negative signal tiers.
/// Biased toward false positives: missing a real emergency is worse
/// than an unnecessary extraction call.
///
/// Single-word keywords use word-boundary regex to avoid partial matches
/// (e.g. "fired" does NOT match "fire"). Multi-word keywords use
/// substring matching.
class EmergencyIntentFilter {
  // ── HIGH SIGNAL (weight +3.0) ──────────────────────────────────────────
  // Unambiguous active-emergency phrases. Rarely appear outside real crises.
  static const _highSignal = <String>{
    'fire',
    'burning',
    'flames',
    'explosion',
    'exploded',
    'trapped',
    'stuck inside',
    'unconscious',
    'not breathing',
    'stopped breathing',
    'dying',
    'dead',
    'bleeding',
    'blood',
    'collapsed',
    'collapse',
    'flooding',
    'flood',
    'earthquake',
    'aftershock',
    'gas leak',
    'chemical spill',
    'downed power',
    'power lines',
    'sos',
    'mayday',
    'call 911',
    'call ambulance',
    'send help',
    'need help now',
    'rescue me',
    'stranded',
    'drowning',
    'electrocution',
    'avalanche',
    'landslide',
    'tornado',
    'hurricane',
    'gunshot',
    'stabbing',
    'choking',
    'seizure',
  };

  // ── MEDIUM SIGNAL (weight +2.0) ────────────────────────────────────────
  // Words that lean toward an active emergency but also appear in general
  // conversation. Require supporting context to cross the threshold.
  static const _medSignal = <String>{
    'emergency',
    'urgent',
    'smoke',
    'injured',
    'injury',
    'wound',
    'medical',
    'ambulance',
    'rescue',
    'hurt',
    'pain',
    'chest pain',
    'heart attack',
    'stroke',
    'hazmat',
    'chemical',
    'danger',
    'dangerous',
    'severe',
    'critical',
    'evacuate',
    'evacuation',
    'paramedic',
    'firefighter',
    'fracture',
    'broken bone',
  };

  // ── LOW SIGNAL (weight +1.0) ────────────────────────────────────────────
  // Weak indicators that slightly lift the score in combination.
  static const _lowSignal = <String>{
    'help',
    'crash',
    'accident',
    'fallen',
    'fell',
    'broke',
    'broken',
    'leak',
    'water',
    'smell',
    'alarm',
  };

  // ── NEGATIVE: STRONG (weight -4.0) ──────────────────────────────────────
  // Unambiguous question starters or hypothetical frames.
  static const _strongNegative = <String>{
    'how do i',
    'how to ',
    'what is ',
    'what are ',
    'what should ',
    'what would ',
    'can you explain',
    'tell me how',
    'tell me what',
    'hypothetically',
    'if there was',
    'if there were',
    'what would happen',
  };

  // ── NEGATIVE: MODERATE (weight -2.0) ────────────────────────────────────
  // Context clues for past events, educational queries, or resolved situations.
  static const _moderateNegative = <String>{
    'prepare for',
    'to prepare',
    'evacuation route',
    'bonfire',
    'campfire',
    'controlled burn',
    'tell me the best',
    'probably a',
    'nothing alarming',
    'already handled',
    'already put out',
    'was put out',
    'last night',
    'last week',
    'yesterday',
    'for example',
    'i read that',
    'i saw on',
    'i watched',
    'documentary',
    'history of',
    'routine check',
    'routine test',
    'hello',
    'hi ',
    'how are you',
    'good morning',
    'good evening',
    'just a test',
    'testing message',
    'learn in case',
    'want to learn',
  };

  /// Score threshold above which the input is classified as an emergency.
  static const double _threshold = 2.0;

  /// Returns `true` if [text] likely describes an emergency.
  ///
  /// Uses weighted scoring with positive and negative signals.
  /// Threshold is [_threshold].
  static bool isEmergency(String text) => score(text) >= _threshold;

  /// Returns the raw emergency score for [text].
  ///
  /// Positive keywords add to the score, negative keywords subtract.
  /// Multi-word keywords use substring matching. Single-word keywords
  /// use word-boundary regex to prevent partial matches.
  static double score(String text) {
    final lower = text.toLowerCase();
    double total = 0.0;

    for (final kw in _highSignal) {
      if (_matchesKeyword(lower, kw)) total += 3.0;
    }
    for (final kw in _medSignal) {
      if (_matchesKeyword(lower, kw)) total += 2.0;
    }
    for (final kw in _lowSignal) {
      if (_matchesKeyword(lower, kw)) total += 1.0;
    }
    // Negatives always use substring (they are phrases, not single words)
    for (final kw in _strongNegative) {
      if (lower.contains(kw)) total -= 4.0;
    }
    for (final kw in _moderateNegative) {
      if (lower.contains(kw)) total -= 2.0;
    }

    return total;
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

  /// Returns matched keywords grouped by tier for debugging / logging.
  static Map<String, List<String>> debugMatches(String text) {
    final lower = text.toLowerCase();
    return {
      'high': _highSignal.where((kw) => _matchesKeyword(lower, kw)).toList(),
      'medium': _medSignal.where((kw) => _matchesKeyword(lower, kw)).toList(),
      'low': _lowSignal.where((kw) => _matchesKeyword(lower, kw)).toList(),
      'strong_negative': _strongNegative
          .where((kw) => lower.contains(kw))
          .toList(),
      'moderate_negative': _moderateNegative
          .where((kw) => lower.contains(kw))
          .toList(),
    };
  }
}
