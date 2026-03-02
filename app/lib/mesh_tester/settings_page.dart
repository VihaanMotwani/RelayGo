import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

class SettingsPage extends StatelessWidget {
  final String adapterName;
  final int storedCount;
  final bool dataPreloaded;
  final bool meshRunning;
  final VoidCallback onPreloadData;
  final VoidCallback onResetDb;
  final VoidCallback onClearLog;

  const SettingsPage({
    super.key,
    required this.adapterName,
    required this.storedCount,
    required this.dataPreloaded,
    required this.meshRunning,
    required this.onPreloadData,
    required this.onResetDb,
    required this.onClearLog,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── TEST DATA ──
        _SectionHeader(title: 'TEST DATA'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.dataset_rounded,
              iconColor: AppColors.blue,
              title: 'Preload Sample Data',
              subtitle: dataPreloaded ? 'Data loaded' : 'Load test reports & messages',
              onTap: dataPreloaded ? null : onPreloadData,
              trailing: dataPreloaded
                  ? const Icon(Icons.check_circle_rounded,
                      size: 20, color: AppColors.green)
                  : const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textTertiary),
            ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.restart_alt_rounded,
              iconColor: AppColors.orange,
              title: 'Reset Database',
              subtitle: meshRunning
                  ? 'Stop relay first'
                  : 'Clear all stored packets',
              onTap: meshRunning ? null : onResetDb,
              destructive: true,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── DEVICE ──
        _SectionHeader(title: 'DEVICE'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.bluetooth_rounded,
              iconColor: AppColors.blue,
              title: 'Bluetooth Adapter',
              subtitle: adapterName,
              onTap: null,
            ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.storage_rounded,
              iconColor: AppColors.purple,
              title: 'Stored Packets',
              subtitle: '$storedCount packets in database',
              onTap: null,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── DEBUG ──
        _SectionHeader(title: 'DEBUG'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.delete_sweep_rounded,
              iconColor: AppColors.textTertiary,
              title: 'Clear Log',
              subtitle: 'Remove all log entries',
              onTap: onClearLog,
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ── Section Header ──

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: AppType.sectionHeader()),
    );
  }
}

// ── Grouped Card ──

class _GroupedCard extends StatelessWidget {
  final List<Widget> children;

  const _GroupedCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator.withAlpha(150)),
      ),
      child: Column(children: children),
    );
  }
}

// ── Tile Divider ──

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 52),
      height: 1,
      color: AppColors.separator.withAlpha(120),
    );
  }
}

// ── Settings Tile ──

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final titleColor = destructive && enabled
        ? AppColors.red
        : (enabled ? AppColors.textPrimary : AppColors.textTertiary);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (enabled ? iconColor : AppColors.textTertiary)
                    .withAlpha(18),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                size: 16,
                color: enabled ? iconColor : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
