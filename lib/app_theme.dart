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

/// Shared corner radii for rectangular surfaces. Circular controls and
/// capsule controls intentionally keep their own geometry.
abstract final class AppRadii {
  static const standard = 14.0;
  static const small = 8.0;
  static const pill = 32.0;
}

/// Shared geometry and typography for interactive controls.
abstract final class AppButtonMetrics {
  static const minWidth = 64.0;
  static const minHeight = 48.0;
  static const height = minHeight;
  static const compactHeight = 44.0;
  static const iconButtonSize = 44.0;
  static const navigationHeight = 64.0;
  static const horizontalPadding = 18.0;
  static const iconGap = 8.0;
  static const radius = AppRadii.standard;
  static const navigationRadius = AppRadii.pill;
  static const loadingIndicatorSize = 20.0;
  static const disabledOpacity = .46;
  static const disabledForegroundOpacity = .38;
  static const interactionDuration = Duration(milliseconds: 140);
  static const labelStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}

/// The common spacing rhythm used by both touch and pointer layouts.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static double pageGutterOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? lg : xl;
}

abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -.6,
  );
  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -.2,
  );
  static const body = TextStyle(fontSize: 15, height: 1.45);
  static const caption = TextStyle(fontSize: 12, height: 1.35);
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
  static const transitionDuration = Duration(milliseconds: 200);
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
      textTheme: baseTheme.textTheme
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
            headlineLarge: AppTextStyles.pageTitle.copyWith(color: text),
            headlineMedium: AppTextStyles.pageTitle.copyWith(
              color: text,
              fontSize: 28,
            ),
            headlineSmall: AppTextStyles.sectionTitle.copyWith(
              color: text,
              fontSize: 22,
            ),
            titleLarge: AppTextStyles.sectionTitle.copyWith(
              color: text,
              fontSize: 22,
            ),
            titleMedium: AppTextStyles.sectionTitle.copyWith(color: text),
            bodyLarge: AppTextStyles.body.copyWith(color: text, fontSize: 16),
            bodyMedium: AppTextStyles.body.copyWith(color: text),
            bodySmall: AppTextStyles.caption.copyWith(color: mutedText),
            labelLarge: AppButtonMetrics.labelStyle.copyWith(color: text),
          ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: .65),
        thickness: .7,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(color: text),
        contentTextStyle: AppTextStyles.body.copyWith(color: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
          borderSide: BorderSide(color: error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.standard),
          borderSide: BorderSide(color: outline.withValues(alpha: .5)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonInteractionStyle(colorScheme, filled: true),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonInteractionStyle(colorScheme, filled: true),
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
        style: _buttonInteractionStyle(colorScheme).copyWith(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(AppButtonMetrics.iconButtonSize),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const WidgetStatePropertyAll(CircleBorder()),
        ),
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
    bool filled = false,
  }) {
    return ButtonStyle(
      animationDuration: AppButtonMetrics.interactionDuration,
      minimumSize: const WidgetStatePropertyAll(
        Size(AppButtonMetrics.minWidth, AppButtonMetrics.minHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppButtonMetrics.horizontalPadding,
          vertical: 12,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppButtonMetrics.radius),
          ),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(AppButtonMetrics.labelStyle),
      iconSize: const WidgetStatePropertyAll(20),
      visualDensity: VisualDensity.standard,
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return (filled ? colorScheme.onPrimary : colorScheme.primary)
              .withValues(alpha: .13);
        }
        if (states.contains(WidgetState.hovered)) {
          return (filled ? colorScheme.onPrimary : colorScheme.primary)
              .withValues(alpha: .08);
        }
        if (states.contains(WidgetState.focused)) {
          return colorScheme.primary.withValues(alpha: .11);
        }
        return Colors.transparent;
      }),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => filled
            ? states.contains(WidgetState.disabled)
                  ? colorScheme.primary.withValues(alpha: .12)
                  : colorScheme.primary
            : Colors.transparent,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colorScheme.onSurface.withValues(
                alpha: AppButtonMetrics.disabledForegroundOpacity,
              )
            : filled
            ? colorScheme.onPrimary
            : colorScheme.primary,
      ),
      elevation: const WidgetStatePropertyAll(0),
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
