import 'package:flutter/material.dart';

/// Central color tokens for the Korvexa dark theme.
///
/// Matches the product design language: near-black neutral surfaces, an indigo
/// accent for interactive states, a soft lavender for filled buttons, and
/// semantic colors for task status and priority.
class AppColors {
  AppColors._();

  // --- Neutral surfaces ---
  static const bg = Color(0xFF0E0F13); // app / main content background
  static const sidebar = Color(0xFF0B0C10); // sidebar (slightly darker)
  static const surface = Color(0xFF17181D); // inputs, panels
  static const surfaceAlt = Color(0xFF1C1D23); // cards on the board
  static const surfaceHover = Color(0xFF23242B);
  static const border = Color(0xFF272931);
  static const borderSubtle = Color(0xFF1E1F26);

  // --- Text ---
  static const textPrimary = Color(0xFFECEDEF);
  static const textSecondary = Color(0xFF9BA1AC);
  static const textMuted = Color(0xFF6B7280);

  // --- Accent (indigo) + lavender filled buttons ---
  static const accent = Color(0xFF6366F1);
  static const accentHover = Color(0xFF7C7EF6);
  static const accentSubtle = Color(0x1A6366F1); // ~10% alpha
  static const lavender = Color(0xFFC4C5F8); // filled-button background
  static const onLavender = Color(0xFF23217A); // filled-button text

  // --- Semantic: task status ---
  static const statusTodo = Color(0xFF8B93A7);
  static const statusInProgress = Color(0xFFF59E0B);
  static const statusDone = Color(0xFF22C55E);

  // --- Semantic: task priority ---
  static const priorityHigh = Color(0xFFEF4444);
  static const priorityMedium = Color(0xFFF97316);
  static const priorityLow = Color(0xFF64748B);

  // --- Feedback ---
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);

  /// Priority color for a task priority value (`low`/`medium`/`high`).
  static Color priority(String value) => switch (value) {
        'high' => priorityHigh,
        'medium' => priorityMedium,
        _ => priorityLow,
      };

  /// Status accent color for a task status value.
  static Color status(String value) => switch (value) {
        'in_progress' => statusInProgress,
        'done' => statusDone,
        _ => statusTodo,
      };

  /// A deterministic accent color for a project, derived from its key so each
  /// project's avatar has a stable, distinct hue.
  static Color forKey(String key) {
    const palette = [
      Color(0xFF6366F1), // indigo
      Color(0xFFF97316), // orange
      Color(0xFF22C55E), // green
      Color(0xFF06B6D4), // cyan
      Color(0xFFEC4899), // pink
      Color(0xFFEAB308), // amber
      Color(0xFF8B5CF6), // violet
      Color(0xFF14B8A6), // teal
    ];
    if (key.isEmpty) return palette.first;
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}
