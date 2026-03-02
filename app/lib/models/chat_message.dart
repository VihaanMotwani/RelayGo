enum ChatRole { user, assistant, system }

enum ConfidenceLevel { verified, meshReport, unverified }

class ChatMessage {
  final String text;
  final ChatRole role;
  final ConfidenceLevel? confidence;
  final DateTime timestamp;
  final bool isVoice;

  ChatMessage({
    required this.text,
    required this.role,
    this.confidence,
    DateTime? timestamp,
    this.isVoice = false,
  }) : timestamp = timestamp ?? DateTime.now();

  String get confidenceLabel {
    switch (confidence) {
      case ConfidenceLevel.verified:
        return 'VERIFIED PROCEDURE';
      case ConfidenceLevel.meshReport:
        return 'MESH REPORT';
      case ConfidenceLevel.unverified:
        return 'UNVERIFIED';
      case null:
        return '';
    }
  }
}
