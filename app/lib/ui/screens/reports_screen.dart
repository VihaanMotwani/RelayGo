import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/mesh_provider.dart';
import '../widgets/report_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshProvider>();
    final reports = mesh.reports
      ..sort((a, b) => b.urg.compareTo(a.urg)); // Sort by urgency desc

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.emergencyRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.list_alt,
                size: 18,
                color: AppTheme.emergencyRed,
              ),
            ),
            const SizedBox(width: 8),
            Text('Reports (${reports.length})'),
          ],
        ),
      ),
      body: reports.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: AppTheme.textMuted.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No emergency reports yet',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reports from the mesh network will appear here',
                    style: TextStyle(
                      color: AppTheme.textMuted.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reports.length,
              itemBuilder: (_, i) => ReportCard(report: reports[i])
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 50 * i))
                  .slideX(begin: 0.05),
            ),
    );
  }
}
