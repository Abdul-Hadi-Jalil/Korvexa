import 'package:flutter/material.dart';

import '../models/label.dart';

/// Parses a "#rrggbb" hex string into a Color; falls back to a neutral grey.
Color labelColor(Label label, {Color fallback = const Color(0xFF9E9E9E)}) {
  final raw = label.color;
  if (raw == null) return fallback;
  var hex = raw.replaceFirst('#', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}

class LabelChip extends StatelessWidget {
  final Label label;
  final VoidCallback? onDeleted;

  const LabelChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final color = labelColor(label);
    return Chip(
      label: Text(label.name, style: const TextStyle(fontSize: 12)),
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      onDeleted: onDeleted,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
