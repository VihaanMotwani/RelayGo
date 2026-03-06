import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'log_service.dart';
import 'theme.dart';

class LogPage extends StatelessWidget {
  final List<LogEntry> entries;
  final ScrollController scrollController;
  final VoidCallback onClear;

  const LogPage({
    super.key,
    required this.entries,
    required this.scrollController,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          child: Row(
            children: [
              Icon(Icons.terminal_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: Spacing.sm),
              Text(
                'Live Log',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Clear',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Log entries ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.lg),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Tap Start Relay or Preload Data\nto see log entries here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms)
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: Spacing.sm),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _LogRow(
                        key: ValueKey(
                            '${entries[i].timestamp.millisecondsSinceEpoch}-$i'),
                        entry: entries[i],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Log Row ──

class _LogRow extends StatelessWidget {
  final LogEntry entry;

  const _LogRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final h = entry.timestamp.hour.toString().padLeft(2, '0');
    final m = entry.timestamp.minute.toString().padLeft(2, '0');
    final s = entry.timestamp.second.toString().padLeft(2, '0');
    final ms = entry.timestamp.millisecond.toString().padLeft(3, '0');
    final time = '$h:$m:$s.$ms';

    final tagColor = _tagColor(entry.tag);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time, 
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.tag,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: tagColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 12,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 180.ms,
          curve: Curves.easeOut,
        );
  }

  static Color _tagColor(String tag) {
    switch (tag) {
      case 'BLE-CENTRAL':
        return Colors.blue.shade600;
      case 'BLE-PERIPH':
        return Colors.green.shade600;
      case 'STORE':
        return Colors.purple.shade600;
      case 'MESH':
        return Colors.orange.shade600;
      case 'ERROR':
        return Colors.red.shade600;
      case 'INFO':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
