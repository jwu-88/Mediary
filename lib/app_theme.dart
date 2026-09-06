import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Edit these semantic color variables to restyle the whole application.
abstract final class AppColors {
  static const accent = Color(0xFF1565C0);
  static const lightAccent = Color(0xFF0A62D0);
  static const darkAccent = Color(0xFF0A84FF);

  static const lightBackground = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1C1C1E);
  static const lightMutedText = Color(0xFF626268);
  static const lightOutline = Color(0xFFC6C6C8);
  static const lightError = Color(0xFFBA1A1A);

  // Keep dark mode deep and calm without collapsing into a harsh pure black.
  static const darkBackground = Color(0xFF0B0C0F);
  static const darkSurface = Color(0xFF202126);
  static const darkText = Color(0xFFF2F2F7);
  static const darkMutedText = Color(0xFFAEAEB2);
  static const darkOutline = Color(0xFF3A3A3C);
  static const darkError = Color(0xFFFFB4AB);
}

/// User-selectable accent palettes. Blue remains Mediary's default.
enum AppAccentColor {
  blue(
    label: 'Blue',
    seed: AppColors.accent,
    light: AppColors.lightAccent,
    dark: AppColors.darkAccent,
  ),
  indigo(
    label: 'Indigo',
    seed: Color(0xFF5146A8),
    light: Color(0xFF4F46A8),
    dark: Color(0xFF7D72FF),
  ),
  purple(
    label: 'Purple',
    seed: Color(0xFF7B3FA1),
    light: Color(0xFF7B3FA1),
    dark: Color(0xFFBF5AF2),
  ),
  teal(
    label: 'Teal',
    seed: Color(0xFF007D82),
    light: Color(0xFF007D82),
    dark: Color(0xFF40CBE0),
  ),
  orange(
    label: 'Orange',
    seed: Color(0xFFB85200),
    light: Color(0xFFB85200),
    dark: Color(0xFFFF9F0A),
  );

  const AppAccentColor({
    required this.label,
    required this.seed,
    required this.light,
    required this.dark,
  });

  final String label;
  final Color seed;
  final Color light;
  final Color dark;

  Color resolve(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

abstract final class AppTheme {
  /// Keeps palette and brightness changes calm enough to read as one motion.
  static const transitionDuration = Duration(milliseconds: 420);
  static const transitionCurve = Curves.easeInOutCubic;

  static final ThemeData light = lightFor(AppAccentColor.blue);

  static final ThemeData dark = darkFor(AppAccentColor.blue);

  static ThemeData lightFor(AppAccentColor accent) => _build(
    brightness: Brightness.light,
    seedColor: accent.seed,
    primary: accent.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    text: AppColors.lightText,
    mutedText: AppColors.lightMutedText,
    outline: AppColors.lightOutline,
    error: AppColors.lightError,
  );

  static ThemeData darkFor(AppAccentColor accent) => _build(
    brightness: Brightness.dark,
    seedColor: accent.seed,
    primary: accent.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    text: AppColors.darkText,
    mutedText: AppColors.darkMutedText,
    outline: AppColors.darkOutline,
    error: AppColors.darkError,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color seedColor,
    required Color primary,
    required Color background,
    required Color surface,
    required Color text,
    required Color mutedText,
    required Color outline,
    required Color error,
  }) {
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final colorScheme = generatedScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
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
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: primary,
      ),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonInteractionStyle(colorScheme, includeElevation: true),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonInteractionStyle(colorScheme, includeElevation: true),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonInteractionStyle(colorScheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonInteractionStyle(colorScheme).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? outline.withValues(alpha: .45)
                  : outline,
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: _buttonInteractionStyle(colorScheme)
            .copyWith(shape: const WidgetStatePropertyAll(CircleBorder())),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : brightness == Brightness.dark
              ? const Color(0xFFE5E5EA)
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : brightness == Brightness.dark
              ? const Color(0xFF48484A)
              : const Color(0xFFE5E5EA),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static ButtonStyle _buttonInteractionStyle(
    ColorScheme colorScheme, {
    bool includeElevation = false,
  }) {
    return ButtonStyle(
      animationDuration: const Duration(milliseconds: 140),
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return colorScheme.primary.withValues(alpha: .16);
        }
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.primary.withValues(alpha: .09);
        }
        if (states.contains(WidgetState.focused)) {
          return colorScheme.primary.withValues(alpha: .11);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colorScheme.onSurface.withValues(alpha: .38)
            : null,
      ),
      elevation: includeElevation
          ? WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled) ||
                  states.contains(WidgetState.pressed)) {
                return 0;
              }
              if (states.contains(WidgetState.hovered)) return 2;
              return 0;
            })
          : null,
    );
  }
}

/// Paints the animated theme background behind every route.
///
/// This prevents the platform's unpainted surface from showing through while
/// Material interpolates between light, dark, system, and accent themes.
class AppThemeTransitionSurface extends StatelessWidget {
  const AppThemeTransitionSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('appThemeTransitionSurface'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
