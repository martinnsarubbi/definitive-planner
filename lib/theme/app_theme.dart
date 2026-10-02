import 'package:flutter/material.dart';

/// Cambiar estos tokens modifica el diseño sin tocar la lógica de los widgets.
abstract final class AppTheme {
  static const colors = [
    Color(0xFF526654),
    Color(0xFF536C91),
    Color(0xFF966449),
    Color(0xFF806399),
  ];
  static const canvas = Color(0xFFF6F5F0);
  static const radius = 18.0;
  static const gap = 16.0;
  static const contentWidth = 1320.0;

  static ThemeData build(int accent, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors[accent.clamp(0, colors.length - 1)],
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamilyFallback: const ['PlannerEmoji'],
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? canvas
          : const Color(0xFF191D1A),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
    );
  }
}
