import 'package:flutter/material.dart';

/// Edit these semantic color variables to restyle the whole application.
abstract final class AppColors {
  static const accent = Color(0xFF1565C0);

  static const lightBackground = Color(0xFFF7F9FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF171C24);
  static const lightMutedText = Color(0xFF44474F);
  static const lightOutline = Color(0xFF74777F);
  static const lightError = Color(0xFFBA1A1A);

  static const darkBackground = Color(0xFF101418);
  static const darkSurface = Color(0xFF181C20);
  static const darkText = Color(0xFFE2E2E9);
  static const darkMutedText = Color(0xFFC4C6D0);
  static const darkOutline = Color(0xFF8E9099);
  static const darkError = Color(0xFFFFB4AB);
}

abstract final class AppTheme {
  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    text: AppColors.lightText,
    mutedText: AppColors.lightMutedText,
    outline: AppColors.lightOutline,
    error: AppColors.lightError,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    text: AppColors.darkText,
    mutedText: AppColors.darkMutedText,
    outline: AppColors.darkOutline,
    error: AppColors.darkError,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color text,
    required Color mutedText,
    required Color outline,
    required Color error,
  }) {
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    );
    final colorScheme = generatedScheme.copyWith(
      surface: surface,
      surfaceDim: surface,
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      onSurface: text,
      onSurfaceVariant: mutedText,
      outline: outline,
      outlineVariant: outline,
      error: error,
    );
    final baseTheme = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
    );

    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(bodyColor: text, displayColor: text),
      dividerTheme: DividerThemeData(color: outline),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(side: BorderSide(color: outline)),
      ),
    );
  }
}
