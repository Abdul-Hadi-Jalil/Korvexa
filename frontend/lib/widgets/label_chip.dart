import 'package:flutter/material.dart';

import '../models/label.dart';
import '../theme/app_colors.dart';

/// Parses a "#rrggbb" hex string into a Color; falls back to the accent.
Color labelColor(Label label, {Color fallback = AppColors.accent}) {
  final raw = label.color;
  if (raw == null) return fallback;
  var hex = raw.replaceFirst('#', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}

/// A small tinted pill for a label: soft colored background with the label's
/// color, readable text, and an optional delete affordance.
class LabelChip extends StatelessWidget {
  final Label label;
  final VoidCallback? onDeleted;

  const LabelChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final color = labelColor(label);
    final text = Color.lerp(color, Colors.white, 0.35)!;
    return Container(
      padding: EdgeInsets.only(left: 8, right: onDeleted == null ? 8 : 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.name, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w500)),
          if (onDeleted != null) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(10),
              child: Icon(Icons.close, size: 13, color: text.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}
