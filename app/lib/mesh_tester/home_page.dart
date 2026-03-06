import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../core/packet_builder.dart';
import '../core/sent_report_cache.dart';
import '../models/extraction_result.dart';
import '../services/location_service.dart';
import 'gemma_service.dart';
import 'instrumented_mesh_service.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  final InstrumentedMeshService mesh;
  final bool meshRunning;
  final VoidCallback onToggleMesh;
  final double? lat;
  final double? lng;
  final GemmaService gemma;
  final SentReportCache reportCache;

  const HomePage({
    super.key,
    required this.mesh,
    required this.meshRunning,
    required this.onToggleMesh,
    this.lat,
    this.lng,
    required this.gemma,
    required this.reportCache,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Report form state ──
  String? _selectedType;
  int _selectedUrg = 3;
  final TextEditingController _descController = TextEditingController();
  bool _isSending = false;
  bool _isShortening = false;
  String? _sendSuccess; // flash message after send

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _selectedType != null &&
      _descController.text.trim().isNotEmpty &&
      _descController.text.trim().length <= 100 &&
      !_isSending;

  Future<void> _sendReport() async {
    if (!_canSend) return;

    setState(() => _isSending = true);

    try {
      final position = await LocationService.getCurrentLocation();
      final deviceId = await widget.mesh.getDeviceAddress();

      final extraction = ExtractionResult(
        type: _selectedType!,
        urg: _selectedUrg,
        desc: _descController.text.trim(),
      );

      final report = PacketBuilder.build(
        extraction: extraction,
        position: position,
        deviceId: deviceId,
      );

      final isNew = await widget.mesh.injectReport(report);

      widget.reportCache.add(
        extraction: extraction,
        eventId: report.eventId,
        ts: report.ts,
        lat: report.lat,
        lng: report.lng,
      );

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _sendSuccess = isNew
            ? '📡 Report sent to mesh'
            : '🔁 Duplicate — already sent';
        // Reset form
        _selectedType = null;
        _selectedUrg = 3;
        _descController.clear();
      });

      // Clear flash message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _sendSuccess = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sendSuccess = '❌ Failed: $e';
      });
    }
  }

  Future<void> _shortenDesc() async {
    if (_isShortening || widget.gemma.status != GemmaStatus.ready) return;

    setState(() => _isShortening = true);

    try {
      final shortened = await widget.gemma.shortenDescription(
        _descController.text.trim(),
      );
      if (shortened != null && mounted) {
        _descController.text = shortened;
      }
    } catch (_) {}

    if (mounted) setState(() => _isShortening = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        children: [
          const SizedBox(height: Spacing.lg),
          _buildHeroButton(context),
          if (widget.meshRunning) ...[
            const SizedBox(height: Spacing.xl),
            _buildReportForm(context),
          ],
          const SizedBox(height: Spacing.lg),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildHeroButton(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final green = Colors.green.shade500;
    final activeColor = widget.meshRunning ? green : primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onToggleMesh,
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
                              widget.meshRunning
                                  ? Icons.cell_tower_rounded
                                  : Icons.power_settings_new_rounded,
                              key: ValueKey(widget.meshRunning),
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate(
                      onPlay: (controller) => widget.meshRunning
                          ? controller.repeat()
                          : controller.stop(),
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
              widget.meshRunning ? 'Relay Active' : 'Start Relay',
              key: ValueKey('title-${widget.meshRunning}'),
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
              widget.meshRunning
                  ? '${widget.mesh.peerCount} peers connected'
                  : 'Tap to begin broadcasting',
              key: ValueKey(
                'subtitle-${widget.meshRunning}-${widget.mesh.peerCount}',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          if (widget.meshRunning &&
              widget.lat != null &&
              widget.lng != null) ...[
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
                    '${widget.lat!.toStringAsFixed(6)}, ${widget.lng!.toStringAsFixed(6)}',
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

  // ── Report Form ────────────────────────────────────────────────────────

  Widget _buildReportForm(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade500,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Send SOS Report',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.reportCache.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '${widget.reportCache.entries.length} sent',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Type picker
          Text('TYPE', style: AppType.sectionHeader()),
          const SizedBox(height: 8),
          _buildTypePicker(theme),
          const SizedBox(height: Spacing.md),

          // Urgency
          Text('URGENCY', style: AppType.sectionHeader()),
          const SizedBox(height: 8),
          _buildUrgencyPicker(theme),
          const SizedBox(height: Spacing.md),

          // Description
          Row(
            children: [
              Text('DESCRIPTION', style: AppType.sectionHeader()),
              const Spacer(),
              Text(
                '${_descController.text.length}/100',
                style: TextStyle(
                  fontSize: 11,
                  color: _descController.text.length > 100
                      ? Colors.red.shade500
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 2,
            maxLength: 150, // Allow typing > 100, but warn
            style: AppType.body(),
            decoration: InputDecoration(
              hintText: 'Describe the emergency…',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.logBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
              counterText: '', // We show our own counter above
            ),
            onChanged: (_) => setState(() {}),
          ),

          // AI Shorten button — only when > 100 chars
          if (_descController.text.length > 100) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isShortening ? null : _shortenDesc,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isShortening)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue.shade500,
                        ),
                      )
                    else
                      Icon(
                        Icons.auto_fix_high_rounded,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isShortening ? 'Shortening…' : 'AI Shorten to 100 chars',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: Spacing.md),

          // Flash message
          if (_sendSuccess != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _sendSuccess!.startsWith('❌')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _sendSuccess!.startsWith('❌')
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Text(
                _sendSuccess!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _sendSuccess!.startsWith('❌')
                      ? Colors.red.shade800
                      : Colors.green.shade800,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Send button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _canSend ? _sendReport : null,
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSending ? 'Sending…' : 'Send to Mesh',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSend
                    ? _urgencyColor(_selectedUrg)
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildTypePicker(ThemeData theme) {
    const types = ExtractionResult.validTypes; // {'fire','medical',...}

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isSelected = _selectedType == type;
        final eType = EmergencyType.fromString(type);
        final icon = _typeIcon(type);

        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : AppColors.logBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  eType.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUrgencyPicker(ThemeData theme) {
    return Row(
      children: List.generate(5, (i) {
        final level = i + 1;
        final isSelected = _selectedUrg == level;
        final color = _urgencyColor(level);
        final label = _urgencyLabel(level);

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedUrg = level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : AppColors.logBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$level',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Helpers ──

  static IconData _typeIcon(String type) => switch (type) {
    'fire' => Icons.local_fire_department_rounded,
    'medical' => Icons.medical_services_rounded,
    'structural' => Icons.domain_disabled_rounded,
    'flood' => Icons.water_rounded,
    'hazmat' => Icons.science_rounded,
    _ => Icons.warning_rounded,
  };

  static Color _urgencyColor(int urg) => switch (urg) {
    5 => const Color(0xFFDC2626),
    4 => const Color(0xFFEA580C),
    3 => const Color(0xFFF59E0B),
    2 => const Color(0xFF3B82F6),
    _ => const Color(0xFF6B7280),
  };

  static String _urgencyLabel(int urg) => switch (urg) {
    5 => 'CRITICAL',
    4 => 'SERIOUS',
    3 => 'HELP',
    2 => 'MINOR',
    _ => 'INFO',
  };
}
