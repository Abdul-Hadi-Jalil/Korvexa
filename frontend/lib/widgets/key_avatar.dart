import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A rounded-square avatar showing a project/workspace key or initials, tinted
/// with a stable color derived from the key. Used on project cards and in the
/// sidebar workspace header.
class KeyAvatar extends StatelessWidget {
  final String label;
  final double size;
  final Color? color;

  const KeyAvatar({super.key, required this.label, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.forKey(label);
    final text = label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: tint.withValues(alpha: 0.40)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Color.lerp(tint, Colors.white, 0.25),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
