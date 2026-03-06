import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'instrumented_mesh_service.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  final InstrumentedMeshService mesh;
  final bool meshRunning;
  final VoidCallback onToggleMesh;
  final double? lat;
  final double? lng;

  const HomePage({
    super.key,
    required this.mesh,
    required this.meshRunning,
    required this.onToggleMesh,
    this.lat,
    this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final ids = mesh.storedPacketIds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Center(child: _buildHeroButton(context)),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildHeroButton(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final green = Colors.green.shade500;

    final activeColor = meshRunning ? green : primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onToggleMesh,
            child:
                Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withOpacity(0.1),
                        border: Border.all(
                          color: activeColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor,
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
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
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate(
                      onPlay: (controller) =>
                          meshRunning ? controller.repeat() : controller.stop(),
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: 1000.ms,
                      curve: Curves.easeInOutSine,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.05, 1.05),
                      end: const Offset(1, 1),
                      duration: 1000.ms,
                      curve: Curves.easeInOutSine,
                    ),
          ),
          const SizedBox(height: Spacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              meshRunning ? 'Relay Active' : 'Start Relay',
              key: ValueKey('title-$meshRunning'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: activeColor,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              meshRunning
                  ? '${mesh.peerCount} peers connected'
                  : 'Tap to begin broadcasting',
              key: ValueKey('subtitle-$meshRunning-${mesh.peerCount}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          if (meshRunning && lat != null && lng != null) ...[
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
