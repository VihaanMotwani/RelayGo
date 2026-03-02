import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Column(
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.terminal_rounded,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(
                'Live Log',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.separator.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entries.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Log entries ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.logBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.separator.withAlpha(150)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Tap Start Relay or Preload Data\nto see log entries here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms)
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: AppType.monoSmall()),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: tagColor.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.tag,
              style: GoogleFonts.sourceCodePro(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: tagColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.message,
              style: GoogleFonts.sourceCodePro(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(
          begin: 0.15,
          end: 0,
          duration: 180.ms,
          curve: Curves.easeOut,
        );
  }

  static Color _tagColor(String tag) {
    switch (tag) {
      case 'BLE-CENTRAL':
        return AppColors.blue;
      case 'BLE-PERIPH':
        return AppColors.green;
      case 'STORE':
        return AppColors.purple;
      case 'MESH':
        return AppColors.orange;
      case 'ERROR':
        return AppColors.red;
      case 'INFO':
        return AppColors.blue;
      default:
        return AppColors.textSecondary;
    }
  }
}
