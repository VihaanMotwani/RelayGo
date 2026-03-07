import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

class SettingsPage extends StatelessWidget {
  final String adapterName;
  final int storedCount;
  final bool dataPreloaded;
  final bool meshRunning;
  final VoidCallback onPreloadData;
  final VoidCallback onResetDb;
  final VoidCallback onClearLog;
  final VoidCallback? onRebuildAiIndex;
  final VoidCallback? onClearAiCache;

  const SettingsPage({
    super.key,
    required this.adapterName,
    required this.storedCount,
    required this.dataPreloaded,
    required this.meshRunning,
    required this.onPreloadData,
    required this.onResetDb,
    required this.onClearLog,
    this.onRebuildAiIndex,
    this.onClearAiCache,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
      children: [
        // ── TEST DATA ──
        _SectionHeader(title: 'TEST DATA'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.dataset_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: 'Preload Sample Data',
              subtitle: dataPreloaded ? 'Data loaded' : 'Load test reports & messages',
              onTap: dataPreloaded ? null : onPreloadData,
              trailing: dataPreloaded
                  ? const Icon(Icons.check_circle_rounded,
                      size: 20, color: Colors.green)
                  : Icon(Icons.chevron_right_rounded,
                      size: 20, color: Colors.grey.shade400),
            ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.restart_alt_rounded,
              iconColor: Colors.orange.shade500,
              title: 'Reset Database',
              subtitle: meshRunning
                  ? 'Stop relay first'
                  : 'Clear all stored packets',
              onTap: meshRunning ? null : onResetDb,
              destructive: true,
            ),
          ],
        ),

        const SizedBox(height: Spacing.xl),

        // ── DEVICE ──
        _SectionHeader(title: 'DEVICE'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.bluetooth_rounded,
              iconColor: Colors.blue.shade500,
              title: 'Bluetooth Adapter',
              subtitle: adapterName,
              onTap: null,
            ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.storage_rounded,
              iconColor: Colors.purple.shade500,
              title: 'Stored Packets',
              subtitle: '$storedCount packets in database',
              onTap: null,
            ),
          ],
        ),

        const SizedBox(height: Spacing.xl),

        // ── AI ──
        _SectionHeader(title: 'AI'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.refresh_rounded,
              iconColor: Colors.teal.shade500,
              title: 'Rebuild Knowledge Index',
              subtitle: 'Reload passages and clear AI cache',
              onTap: onRebuildAiIndex,
            ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.cleaning_services_rounded,
              iconColor: Colors.orange.shade500,
              title: 'Clear AI Cache',
              subtitle: 'Delete all cached AI responses',
              onTap: onClearAiCache,
              destructive: true,
            ),
          ],
        ),

        const SizedBox(height: Spacing.xl),

        // ── DEBUG ──
        _SectionHeader(title: 'DEBUG'),
        _GroupedCard(
          children: [
            _SettingsTile(
              icon: Icons.delete_sweep_rounded,
              iconColor: Colors.grey.shade500,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: Spacing.sm),
      child: Text(
        title, 
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Grouped Card ──

class _GroupedCard extends StatelessWidget {
  final List<Widget> children;

  const _GroupedCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
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
      margin: const EdgeInsets.only(left: 56),
      height: 1,
      color: Theme.of(context).dividerColor,
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
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final titleColor = destructive && enabled
        ? Colors.red.shade600
        : (enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.4));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (enabled ? iconColor : Colors.grey.shade400).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled ? iconColor : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
