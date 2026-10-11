// Palette (matched to web tokens).

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFFF4F5F7);
  static const backgroundDark = Color(0xFF09090B);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceHover = Color(0xFFF0F2F5);
  static const border = Color(0xFFE4E6EB);

  static const textPrimary = Color(0xFF0F1115);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF8B919A);

  static const accent = Color(0xFF2563EB);
  static const accentMuted = Color(0x1F2563EB);

  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);

  static const primary = Color(0xFF1F1F1F);
  static const white = Colors.white;

  static AppPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? AppPalette.dark : AppPalette.light;
  }
}

class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHover,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentMuted,
    required this.success,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHover;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentMuted;
  final Color success;
  final Color error;

  static const light = AppPalette(
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF0F2F5),
    border: Color(0xFFE4E6EB),
    textPrimary: Color(0xFF0F1115),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF8B919A),
    accent: Color(0xFF2563EB),
    accentMuted: Color(0x1F2563EB),
    success: Color(0xFF16A34A),
    error: Color(0xFFDC2626),
  );

  static const dark = AppPalette(
    background: Color(0xFF09090B),
    surface: Color(0xFF111113),
    surfaceElevated: Color(0xFF18181B),
    surfaceHover: Color(0xFF1F1F23),
    border: Color(0xFF27272A),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    accent: Color(0xFF3B82F6),
    accentMuted: Color(0x333B82F6),
    success: Color(0xFF22C55E),
    error: Color(0xFFEF4444),
  );
}
