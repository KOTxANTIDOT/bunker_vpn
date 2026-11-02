import 'package:flutter/material.dart';

abstract final class BunkerColors {
  static const background = Color(0xFF0B0D12);
  static const surface = Color(0xFF141923);
  static const surfaceRaised = Color(0xFF1B2330);
  static const accent = Color(0xFFB8FF3B);
  static const textPrimary = Color(0xFFF2F5F8);
  static const textMuted = Color(0xFF8993A2);
  static const border = Color(0xFF283241);
}

abstract final class BunkerTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: BunkerColors.accent,
      brightness: Brightness.dark,
      surface: BunkerColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: BunkerColors.accent,
        onPrimary: BunkerColors.background,
        surface: BunkerColors.surface,
      ),
      scaffoldBackgroundColor: BunkerColors.background,
      cardColor: BunkerColors.surface,
      dividerColor: BunkerColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: BunkerColors.background,
        foregroundColor: BunkerColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: BunkerColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        titleLarge: TextStyle(
          color: BunkerColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: BunkerColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BunkerColors.accent,
          foregroundColor: BunkerColors.background,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
