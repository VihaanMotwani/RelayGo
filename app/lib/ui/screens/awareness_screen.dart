import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/awareness_provider.dart';
import '../widgets/awareness_card.dart';

class AwarenessScreen extends StatefulWidget {
  const AwarenessScreen({super.key});

  @override
  State<AwarenessScreen> createState() => _AwarenessScreenState();
}

class _AwarenessScreenState extends State<AwarenessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AwarenessProvider>().refresh(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final awareness = context.watch<AwarenessProvider>();
    final summary = awareness.summary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.shield,
                size: 18,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Disaster Awareness'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: awareness.isGenerating
                ? null
                : () => awareness.refresh(force: true),
            icon: awareness.isGenerating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.cyan,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last updated + data counts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.update, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_timeAgo(summary.generatedAt)}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.reportCount} reports | ${summary.messageCount} messages',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            AwarenessCard(
              title: 'Situation Overview',
              content: summary.situation,
              icon: Icons.info_outline,
              color: AppTheme.cyan,
              isConfirmed: summary.reportCount > 2,
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),

            AwarenessCard(
              title: 'Active Threats',
              content: summary.threats,
              icon: Icons.warning_amber,
              color: AppTheme.emergencyRed,
              isConfirmed: summary.reportCount > 3,
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),

            AwarenessCard(
              title: 'Guidance',
              content: summary.guidance,
              icon: Icons.directions,
              color: const Color(0xFF00CC66),
              isConfirmed: true,
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),

            AwarenessCard(
              title: 'Areas Needing Help',
              content: summary.needsHelp,
              icon: Icons.people,
              color: Colors.amber,
              isConfirmed: summary.reportCount > 1,
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
