import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/emergency_report.dart';

class ReportCard extends StatelessWidget {
  final EmergencyReport report;

  const ReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final typeColor = AppTheme.colorForType(report.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: typeColor,
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  report.type.toUpperCase(),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _UrgencyBadge(urgency: report.urg),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.desc,
              style: const TextStyle(
                color: AppTheme.textColor,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  _timeAgo(report.dateTime),
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 12),
                Icon(Icons.route, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${report.hops} hops',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                if (report.haz.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.haz.join(', '),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _UrgencyBadge extends StatelessWidget {
  final int urgency;

  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (urgency) {
      case 5:
        color = AppTheme.emergencyRed;
        label = 'CRITICAL';
      case 4:
        color = Colors.orange;
        label = 'HIGH';
      case 3:
        color = Colors.amber;
        label = 'MEDIUM';
      default:
        color = AppTheme.textMuted;
        label = 'LOW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$urgency $label',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
