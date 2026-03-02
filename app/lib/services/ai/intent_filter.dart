/// Lightweight keyword-based pre-filter that estimates whether a user message
/// is describing an active emergency. Runs in ~0ms with no model dependency.
///
/// Used to gate the LLM extraction tool call so that casual messages like
/// "hello" or "what is CPR?" never trigger false emergency reports.
class IntentFilter {
  // ── HIGH SIGNAL (weight +3.0) ──────────────────────────────────────────
  // Unambiguous active-emergency phrases. Rarely appear outside real crises.
  static const _highSignal = {
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
  };

  // ── MEDIUM SIGNAL (weight +2.0) ────────────────────────────────────────
  // Words that lean toward an active emergency but also appear in general
  // conversation. Require supporting context to cross the threshold.
  // NOTE: "building" and "help" are intentionally excluded — too generic.
  static const _medSignal = {
    'emergency',
    'urgent',
    'smoke',
    'gas',
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
    'overflow',
    'structural',
    'hazmat',
    'chemical',
    'spill',
    'danger',
    'dangerous',
    'lost',
    'no food',
    'no water',
  };

  // ── LOW SIGNAL (weight +1.0) ────────────────────────────────────────────
  // Weak indicators that slightly lift the score in combination.
  static const _lowSignal = {
    'help',
    'police',
    'crash',
    'accident',
    'fallen',
    'fell',
    'broke',
    'broken',
    'leak',
    'water',
    'smell',
    'smoke alarm',
    'alarm',
  };

  // ── NEGATIVE SIGNAL (suppress score) ──────────────────────────────────
  // Patterns that indicate educational, historical, or casual context.
  // Split into strong (-4.0) and moderate (-2.0) tiers.

  /// Strong negative: unambiguous question starters or hypothetical frames.
  /// Weight: -4.0 — strong enough to cancel a single high-signal keyword.
  static const _strongNegative = {
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
    'how high',   // e.g. "how high does flood water need to be"
  };

  /// Moderate negative: context clues for past events, educational queries,
  /// safety drills, or resolved situations.
  /// Weight: -2.0
  static const _moderateNegative = {
    'prepare for',
    'to prepare',
    'how high',
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
    'app working',
    'weather',
    'just letting',
    'learn in case',
    'want to learn',
  };

  /// Score threshold above which the input is classified as an emergency.
  static const double _threshold = 2.0;

  /// Returns `true` if the input looks like an active emergency description.
  static bool isLikelyEmergency(String text) => score(text) >= _threshold;

  /// Returns the raw emergency score for [text].
  static double score(String text) {
    final lower = text.toLowerCase();
    double total = 0.0;

    for (final kw in _highSignal) {
      if (lower.contains(kw)) total += 3.0;
    }
    for (final kw in _medSignal) {
      if (lower.contains(kw)) total += 2.0;
    }
    for (final kw in _lowSignal) {
      if (lower.contains(kw)) total += 1.0;
    }
    for (final kw in _strongNegative) {
      if (lower.contains(kw)) total -= 4.0;
    }
    for (final kw in _moderateNegative) {
      if (lower.contains(kw)) total -= 2.0;
    }

    return total;
  }

  /// Returns matched keywords grouped by tier for debugging / logging.
  static Map<String, List<String>> debugMatches(String text) {
    final lower = text.toLowerCase();
    return {
      'high': _highSignal.where((kw) => lower.contains(kw)).toList(),
      'medium': _medSignal.where((kw) => lower.contains(kw)).toList(),
      'low': _lowSignal.where((kw) => lower.contains(kw)).toList(),
      'strong_negative':
          _strongNegative.where((kw) => lower.contains(kw)).toList(),
      'moderate_negative':
          _moderateNegative.where((kw) => lower.contains(kw)).toList(),
    };
  }
}
