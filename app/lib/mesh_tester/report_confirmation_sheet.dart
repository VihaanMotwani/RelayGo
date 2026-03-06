import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/extraction_result.dart';
import 'theme.dart';

/// Urgency level → colour mapping.
Color _urgencyColor(int urg) => switch (urg) {
  5 => const Color(0xFFDC2626), // red — life threatening
  4 => const Color(0xFFEA580C), // orange — serious
  3 => const Color(0xFFF59E0B), // amber — needs help soon
  2 => const Color(0xFF3B82F6), // blue — minor
  _ => const Color(0xFF6B7280), // grey — informational
};

/// Shows a modal bottom sheet for the user to review and confirm
/// an extracted emergency report before broadcasting it on the mesh.
///
/// Returns `true` if the user confirms (taps Send), `false` if dismissed.
/// [extraction] may be mutated (desc edited) if the user changes the description.
Future<ReportConfirmationResult?> showReportConfirmation(
  BuildContext context, {
  required ExtractionResult extraction,
  required Position? position,
  bool isUpdate = false,
}) {
  return showModalBottomSheet<ReportConfirmationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConfirmationSheet(
      extraction: extraction,
      position: position,
      isUpdate: isUpdate,
    ),
  );
}

/// Result returned by the confirmation sheet.
class ReportConfirmationResult {
  /// The (potentially user-edited) description.
  final String desc;

  /// The confirmed type (user may have tapped to accept).
  final String type;

  /// The confirmed urgency.
  final int urg;

  const ReportConfirmationResult({
    required this.desc,
    required this.type,
    required this.urg,
  });
}

class _ConfirmationSheet extends StatefulWidget {
  final ExtractionResult extraction;
  final Position? position;
  final bool isUpdate;

  const _ConfirmationSheet({
    required this.extraction,
    required this.position,
    required this.isUpdate,
  });

  @override
  State<_ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends State<_ConfirmationSheet> {
  late final TextEditingController _descController;
  late final Set<String> _confirmedFields; // fields user has tapped to confirm

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.extraction.desc);

    // Auto-confirm fields with high confidence
    _confirmedFields = {};
    if (widget.extraction.typeConfidence == FieldConfidence.high) {
      _confirmedFields.add('type');
    }
    if (widget.extraction.urgConfidence == FieldConfidence.high) {
      _confirmedFields.add('urg');
    }
    if (widget.extraction.descConfidence == FieldConfidence.high) {
      _confirmedFields.add('desc');
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  bool get _canSend {
    final descOk =
        _descController.text.trim().isNotEmpty &&
        _descController.text.trim().length <= 100;
    final allConfirmed = _confirmedFields.containsAll({'type', 'urg', 'desc'});
    return descOk && allConfirmed;
  }

  void _toggleConfirm(String field) {
    setState(() {
      _confirmedFields.add(field);
    });
  }

  @override
  Widget build(BuildContext context) {
    final urg = widget.extraction.urg;
    final urgColor = _urgencyColor(urg);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Urgency colour strip + title
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: urgColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: urgColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: urgColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isUpdate
                            ? 'Update Existing Report?'
                            : 'Send Emergency Report?',
                        style: AppType.title(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: urgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'URG $urg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Field chips
              Text('FIELDS', style: AppType.sectionHeader()),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFieldChip(
                    label: 'Type: ${widget.extraction.type}',
                    field: 'type',
                    confidence: widget.extraction.typeConfidence,
                  ),
                  _buildFieldChip(
                    label: 'Urgency: $urg/5',
                    field: 'urg',
                    confidence: widget.extraction.urgConfidence,
                  ),
                  if (widget.extraction.haz.isNotEmpty)
                    ...widget.extraction.haz.map(
                      (h) => Chip(
                        label: Text(h, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.orange.shade50,
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Description field (editable)
              Text('DESCRIPTION', style: AppType.sectionHeader()),
              const SizedBox(height: 8),

              TextField(
                controller: _descController,
                maxLines: 2,
                maxLength: 100,
                style: AppType.body(),
                decoration: InputDecoration(
                  hintText: 'Emergency description...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.logBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  counterStyle: TextStyle(
                    color: _descController.text.length > 100
                        ? Colors.red
                        : AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                onChanged: (_) {
                  // Auto-confirm desc once user edits it
                  _confirmedFields.add('desc');
                  setState(() {});
                },
              ),

              const SizedBox(height: 12),

              // GPS row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.logBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.position != null
                          ? '${widget.position!.latitude.toStringAsFixed(6)}, '
                                '${widget.position!.longitude.toStringAsFixed(6)}'
                          : 'Location unavailable',
                      style: AppType.monoSmall(),
                    ),
                    const Spacer(),
                    if (widget.position != null)
                      Text(
                        '±${widget.position!.accuracy.toStringAsFixed(0)}m',
                        style: AppType.monoSmall(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Send button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _canSend
                      ? () {
                          Navigator.of(context).pop(
                            ReportConfirmationResult(
                              desc: _descController.text.trim(),
                              type: widget.extraction.type,
                              urg: widget.extraction.urg,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSend ? urgColor : Colors.grey.shade300,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.isUpdate ? 'Update Report' : 'Send to Mesh',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldChip({
    required String label,
    required String field,
    required FieldConfidence confidence,
  }) {
    final isConfirmed = _confirmedFields.contains(field);
    final needsConfirmation =
        confidence != FieldConfidence.high && !isConfirmed;

    return GestureDetector(
      onTap: needsConfirmation ? () => _toggleConfirm(field) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isConfirmed ? Colors.green.shade50 : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isConfirmed ? Colors.green.shade300 : Colors.amber.shade400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (needsConfirmation) ...[
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 6),
            ] else ...[
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isConfirmed
                    ? Colors.green.shade800
                    : Colors.amber.shade900,
              ),
            ),
            if (needsConfirmation) ...[
              const SizedBox(width: 6),
              Text(
                'TAP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
