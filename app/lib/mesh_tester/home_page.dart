import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'instrumented_mesh_service.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  final InstrumentedMeshService mesh;
  final bool meshRunning;
  final VoidCallback onToggleMesh;

  const HomePage({
    super.key,
    required this.mesh,
    required this.meshRunning,
    required this.onToggleMesh,
  });

  @override
  Widget build(BuildContext context) {
    final ids = mesh.storedPacketIds;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // ── Hero relay button ──
        _buildHeroButton(context),
        const SizedBox(height: 32),

        // ── Stats card ──
        _buildStatsCard(ids),
        const SizedBox(height: 16),

        // ── Packet ID chips ──
        if (ids.isNotEmpty) _buildPacketChips(ids),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildHeroButton(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleMesh,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: meshRunning
                    ? AppColors.green.withAlpha(20)
                    : AppColors.blue.withAlpha(15),
                border: Border.all(
                  color: meshRunning
                      ? AppColors.green.withAlpha(100)
                      : AppColors.blue.withAlpha(60),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (meshRunning ? AppColors.green : AppColors.blue)
                        .withAlpha(meshRunning ? 30 : 15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  meshRunning
                      ? Icons.cell_tower_rounded
                      : Icons.power_settings_new_rounded,
                  key: ValueKey(meshRunning),
                  size: 48,
                  color: meshRunning ? AppColors.green : AppColors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              meshRunning ? 'Relay Active' : 'Start Relay',
              key: ValueKey('title-$meshRunning'),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: meshRunning ? AppColors.green : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              meshRunning
                  ? '${mesh.peerCount} peers connected'
                  : 'Tap to begin broadcasting',
              key: ValueKey('subtitle-$meshRunning-${mesh.peerCount}'),
              style: AppType.label(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<String> ids) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator.withAlpha(180)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              key: ValueKey('stored-${ids.length}'),
              value: ids.length,
              label: 'Stored',
              color: AppColors.purple,
            ),
          ),
          const _VerticalDivider(),
          Expanded(
            child: _StatBlock(
              key: ValueKey('reports-${mesh.receivedReports}'),
              value: mesh.receivedReports,
              label: 'Reports Rx',
              color: AppColors.blue,
            ),
          ),
          const _VerticalDivider(),
          Expanded(
            child: _StatBlock(
              key: ValueKey('msgs-${mesh.receivedMessages}'),
              value: mesh.receivedMessages,
              label: 'Messages Rx',
              color: AppColors.green,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPacketChips(List<String> ids) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator.withAlpha(180)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PACKET IDS', style: AppType.sectionHeader()),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ids.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.purple.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ids[i].substring(0, 8),
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private helpers ──

class _StatBlock extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _StatBlock({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: AppType.stat().copyWith(color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppType.label()),
      ],
    ).animate().fadeIn(duration: 200.ms).slideY(
          begin: 0.15,
          end: 0,
          duration: 200.ms,
          curve: Curves.easeOut,
        );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.separator.withAlpha(120),
    );
  }
}
