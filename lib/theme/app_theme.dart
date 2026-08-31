import 'package:flutter/material.dart';

/// Locally bundled font helpers (Baloo2 / NunitoSans ship as assets — see
/// pubspec.yaml — rather than being fetched at runtime, so the app works
/// fully offline from first launch).
class AppFonts {
  static TextStyle baloo2({
    FontWeight fontWeight = FontWeight.w400,
    double? fontSize,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Baloo2',
      fontWeight: fontWeight,
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle nunitoSans({
    FontWeight fontWeight = FontWeight.w400,
    double? fontSize,
    Color? color,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'NunitoSans',
      fontWeight: fontWeight,
      fontSize: fontSize,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }
}

/// "Derin Su" (Deep Water) palette — bold, gamified, fishing/nature themed.
class AppColors {
  // Core brand
  static const deepBlue = Color(0xFF0B3D57);
  static const teal = Color(0xFF12808C);
  static const seafoam = Color(0xFF1E9E8C);
  static const moss = Color(0xFF3FA34D);
  static const amber = Color(0xFFFFC94D);
  static const orange = Color(0xFFFF9F43);
  static const slateBlue = Color(0xFF5B6EE1);

  static const bgLight = Color(0xFFEAF6F5);
  static const cardLight = Color(0xFFFFFFFF);
  static const mintTint = Color(0xFFDDEFED);
  static const successBg = Color(0xFFE4F8E9);
  static const successFg = Color(0xFF1E7A3D);
  static const dangerBg = Color(0xFFFCE7E2);
  static const dangerFg = Color(0xFFC0472B);

  static const bgDark = Color(0xFF07141D);
  static const cardDark = Color(0xFF0F2A38);
  static const mintTintDark = Color(0xFF163541);

  /// The 6 category accent colors, in official-category order.
  static const categoryAccents = [deepBlue, teal, seafoam, moss, orange, slateBlue];

  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepBlue, teal],
  );
}

class AppTheme {
  static TextTheme _textTheme(TextTheme base, Color body, Color display) {
    return base.copyWith(
      displayLarge: AppFonts.baloo2(fontWeight: FontWeight.w800, color: display),
      displayMedium: AppFonts.baloo2(fontWeight: FontWeight.w800, color: display),
      displaySmall: AppFonts.baloo2(fontWeight: FontWeight.w800, color: display),
      headlineLarge: AppFonts.baloo2(fontWeight: FontWeight.w700, color: display),
      headlineMedium: AppFonts.baloo2(fontWeight: FontWeight.w700, color: display),
      headlineSmall: AppFonts.baloo2(fontWeight: FontWeight.w700, color: display),
      titleLarge: AppFonts.baloo2(fontWeight: FontWeight.w700, color: display),
      titleMedium: AppFonts.baloo2(fontWeight: FontWeight.w600, color: display),
      bodyLarge: AppFonts.nunitoSans(color: body),
      bodyMedium: AppFonts.nunitoSans(color: body),
      bodySmall: AppFonts.nunitoSans(color: body),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepBlue,
      brightness: Brightness.light,
      primary: AppColors.deepBlue,
      secondary: AppColors.teal,
      error: AppColors.dangerFg,
      surface: AppColors.cardLight,
      surfaceContainerHigh: AppColors.cardLight,
      secondaryContainer: AppColors.mintTint,
    );
    return _base(scheme, AppColors.bgLight);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seafoam,
      brightness: Brightness.dark,
      primary: AppColors.seafoam,
      secondary: AppColors.amber,
      error: const Color(0xFFE28B6D),
      surface: AppColors.cardDark,
      surfaceContainerHigh: AppColors.cardDark,
      secondaryContainer: AppColors.mintTintDark,
    );
    return _base(scheme, AppColors.bgDark);
  }

  static ThemeData _base(ColorScheme scheme, Color scaffoldBg) {
    final textTheme = _textTheme(ThemeData(brightness: scheme.brightness).textTheme, scheme.onSurface, scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 22, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: scheme.surfaceContainerHigh,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(AppFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }
}

/// Semantic colors for quiz answer feedback, independent of theme brightness.
class AnswerColors {
  static const correctFallback = AppColors.moss;
  static const incorrectFallback = AppColors.dangerFg;
}
