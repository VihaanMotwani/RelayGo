import 'dart:async';

import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../mesh/packet_store.dart';
import 'ai_service.dart';

class AwarenessSummary {
  final String situation;
  final String threats;
  final String guidance;
  final String needsHelp;
  final DateTime generatedAt;
  final int reportCount;
  final int messageCount;

  AwarenessSummary({
    required this.situation,
    required this.threats,
    required this.guidance,
    required this.needsHelp,
    required this.generatedAt,
    required this.reportCount,
    required this.messageCount,
  });

  factory AwarenessSummary.empty() => AwarenessSummary(
    situation: 'No data yet. Reports from the mesh network will appear here.',
    threats: 'None detected',
    guidance: 'Stay safe and monitor this screen for updates.',
    needsHelp: 'No reports yet',
    generatedAt: DateTime.now(),
    reportCount: 0,
    messageCount: 0,
  );

  factory AwarenessSummary.fromRawText(String text, int reports, int messages) {
    String situation = '';
    String threats = '';
    String guidance = '';
    String needsHelp = '';

    final lines = text.split('\n');
    String currentSection = '';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('SITUATION:')) {
        currentSection = 'situation';
        situation = trimmed.substring('SITUATION:'.length).trim();
      } else if (trimmed.startsWith('THREATS:')) {
        currentSection = 'threats';
        threats = trimmed.substring('THREATS:'.length).trim();
      } else if (trimmed.startsWith('GUIDANCE:')) {
        currentSection = 'guidance';
        guidance = trimmed.substring('GUIDANCE:'.length).trim();
      } else if (trimmed.startsWith('NEEDS HELP:')) {
        currentSection = 'needsHelp';
        needsHelp = trimmed.substring('NEEDS HELP:'.length).trim();
      } else if (trimmed.isNotEmpty) {
        switch (currentSection) {
          case 'situation':
            situation += '\n$trimmed';
          case 'threats':
            threats += '\n$trimmed';
          case 'guidance':
            guidance += '\n$trimmed';
          case 'needsHelp':
            needsHelp += '\n$trimmed';
        }
      }
    }

    // Fallback if parsing didn't find sections
    if (situation.isEmpty && threats.isEmpty) {
      situation = text;
    }

    return AwarenessSummary(
      situation: situation.isNotEmpty ? situation : 'Processing...',
      threats: threats.isNotEmpty ? threats : 'Analyzing...',
      guidance: guidance.isNotEmpty ? guidance : 'Gathering data...',
      needsHelp: needsHelp.isNotEmpty ? needsHelp : 'Checking reports...',
      generatedAt: DateTime.now(),
      reportCount: reports,
      messageCount: messages,
    );
  }
}

class AwarenessService {
  final AiService _aiService;
  final PacketStore _packetStore;
  DateTime? _lastGenerated;
  static const _minInterval = Duration(seconds: 60);

  AwarenessService(this._aiService, this._packetStore);

  Future<AwarenessSummary> generateSummary({bool force = false}) async {
    // Debounce: don't regenerate too frequently
    if (!force && _lastGenerated != null) {
      final elapsed = DateTime.now().difference(_lastGenerated!);
      if (elapsed < _minInterval) {
        return AwarenessSummary.empty();
      }
    }

    final reports = await _packetStore.getAllReports();
    final messages = await _packetStore.getAllMessages();

    if (reports.isEmpty && messages.isEmpty) {
      return AwarenessSummary.empty();
    }

    final broadcastMessages = messages
        .where((m) => m.isBroadcast)
        .map((m) => '${m.name}: ${m.body}')
        .toList();

    final rawText = await _aiService.generateAwarenessSummary(
      reports,
      broadcastMessages,
    );

    _lastGenerated = DateTime.now();

    return AwarenessSummary.fromRawText(
      rawText,
      reports.length,
      messages.length,
    );
  }
}
