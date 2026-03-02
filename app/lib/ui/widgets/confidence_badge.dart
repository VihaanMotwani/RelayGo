import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

class ConfidenceBadge extends StatelessWidget {
  final ConfidenceLevel level;

  const ConfidenceBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (level) {
      case ConfidenceLevel.verified:
        color = const Color(0xFF00CC66);
        label = 'VERIFIED PROCEDURE';
        icon = Icons.verified;
      case ConfidenceLevel.meshReport:
        color = const Color(0xFF00D9FF);
        label = 'MESH REPORT';
        icon = Icons.cell_tower;
      case ConfidenceLevel.unverified:
        color = const Color(0xFFFF8800);
        label = 'UNVERIFIED';
        icon = Icons.warning_amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
